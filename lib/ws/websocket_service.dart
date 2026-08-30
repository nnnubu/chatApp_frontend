import 'dart:async';
import 'dart:collection';
import 'package:chatapp/api/config.dart';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/ws/ack_helper.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/heart_beat.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_client.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

// WebSocketStatus.connected 通道已连接
// WebSocketMessageType.ready 后端已就绪
// ConnectionHealth.healthy 链路健康 前面两者都可能存在网络半开放的风险 此处是真正判定连接有效的位置

class WebSocketService {
  // 外部在第一次 调用 WebSocketService.instance 时 自动执行 _internal 私有构造函数 禁止外部构造 后续调用会直接复用 旧的实例
  // 全局单例 一个用户的一台设备仅能建立一个连接
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal() {
    // 绑定发送 ping 的实现
    // ping 发送失败 触发监听事件 ErrorEvent 断开连接
    _heartBeat.sendPingCallback = () async {
      final pingDto = MessageDto(msgType: MessageType.heartBeat, data: {});
      return sendDto(pingDto);
    };

    // 心跳连续丢失 判定连接死亡 主动断开连接
    _heartBeat.onConnectDead = () async {
      await _forceCloseConnection();
    };

    // 心跳健康 重置重连退避时间
    _healthSub = _heartBeat.healthStream.listen((health) {
      if (health == ConnectionHealth.healthy) {
        debugPrint("链路双向通信验证成功，重置重连退避时长与可用重连次数");
        _reconnectDelay = const Duration(seconds: 1);
        _availableReconnectCount = 5;
        _allowReconnect = true;
        autoReconnectExhausted.value = false;
        isManuallyReconnecting.value = false;
      }
      // 心跳健康 唤醒队列
      unawaited(_startConsumeOutGoing());
    });

    _ackRespSub = ackHelper.ackRespStream.listen((resp) {
      try {
        if (resp.ackStatus == AckStatus.retry) {
          // ACK 超时，自动重试：将消息重新加入队列
          if (resp.dto != null) {
            // 先移除队列中相同 requestId 的旧消息，避免队列越积越多
            // 连接不正常时消息不会被消费出队，每次重试都会残留一份
            _outGoingQueue.removeWhere((e) => e.requestId == resp.dto!.requestId);
            _outGoingQueue.add(resp.dto!);
            unawaited(_startConsumeOutGoing());
          }
          return;
        } else if (resp.ackStatus == AckStatus.roamed) {
          // 重试次数用尽，消息被流放，聊天页面会显示感叹号
          debugPrint("消息已被流放 requestId:${resp.requestId}");
          debugPrint("漫游队列长度：${ackHelper.roamedMsgList.length}");
          return;
        } else if (resp.ackStatus == AckStatus.failed) {
          // 保留兼容，实际不再触发（超时后自动重试或流放）
          debugPrint("消息：${resp.requestId} 发送失败");
          return;
        }
        // success：消费成功，继续消费下一条
        debugPrint("消费成功 requestId:${resp.requestId}");
        unawaited(_startConsumeOutGoing());
      } catch (e, stack) {
        debugPrint("ackResp 回调异常：$e\n$stack");
      }
    });
  }

  late final StreamSubscription<WebSocketEvent> _eventSub;
  late final WebsocketConnector _connector = WebsocketConnector();

  late final StreamSubscription<ConnectionHealth> _healthSub;
  late final HeartBeat _heartBeat = HeartBeat();

  late final StreamSubscription<AckResponse> _ackRespSub;
  late final AckHelper ackHelper = AckHelper();

  WebSocketStatus get status => _connector.status;
  String get baseUrl => "${ApiConfig.wsUrl}/ws/connect";
  /// 链路是否可发送消息（连接正常+后端就绪+心跳健康）
  bool get canSend =>
      _connector.status == WebSocketStatus.connected &&
      backendReady.value &&
      _heartBeat.currentHealth != ConnectionHealth.dead;

  bool _initedInternalListener = false;
  String token = Get.find<UserController>().token;

  // 重连 主动退出则禁止重连  异常断线允许重连
  bool _allowReconnect = false;
  // 重连定时器 防并发重连
  Timer? _reconnectTimer;
  // 当前重连等待间隔 使用指数退避
  Duration _reconnectDelay = const Duration(seconds: 1);
  // 最大重连间隔
  static const Duration _maxReconnectDelay = Duration(seconds: 8);
  // 可用重连次数
  int _availableReconnectCount = 5;
  // 重连次数耗尽与否 用于用户手动重连
  final RxBool autoReconnectExhausted = false.obs;
  // 是否正在执行用户手动触发的重连 防止重复点击
  final RxBool isManuallyReconnecting = false.obs;

  // 后端业务层是否就绪（收到 ready）
  final RxBool backendReady = false.obs;
  // 心跳链路健康状态
  final Rx<ConnectionHealth> connectionHealth = ConnectionHealth.unconfirmed.obs;
  // 等待就绪信号的计时器
  Timer? _waitReadyTimer;
  // 等待就绪最大时长
  static const _waitReadyTimeout = Duration(seconds: 3);

  Future<void> connect(String token) async {
    // 建立连接 则开启自动重连权限 并重置连接耗尽标记
    _allowReconnect = true;
    // 全局仅初始化一次底层监听，防止重复订阅
    if (!_initedInternalListener) {
      _initedInternalListener = true;
      _eventSub = _connector.eventStream.listen((event) {
        if (event is StatusChange) {
          if (event.status == WebSocketStatus.connected) {
            debugPrint("底层 WebSocket 通道建立成功，等待后端 ready 就绪通知");
            // 标记后端尚未就绪
            backendReady.value = false;
            // 销毁上一个计时器 并启动新的计时器
            _waitReadyTimer?.cancel();
            _waitReadyTimer = Timer(_waitReadyTimeout, () async {
              debugPrint("等待后端 ready 超时，判定初始化失败，异常断开重连");
              await _forceCloseConnection();
            });
          } else if (event.status == WebSocketStatus.closed ||
              event.status == WebSocketStatus.error) {
            // 连接断开 或 异常 停止心跳
            _waitReadyTimer?.cancel();
            backendReady.value = false;
            _heartBeat.stop();

            if (_allowReconnect) {
              _reconnect();
            }
          }
        } else if (event is MessageEvent) {
          if (event.dto.msgType == MessageType.ready) {
            debugPrint("后端 ready 允许正常通信");
            _waitReadyTimer?.cancel();
            backendReady.value = true;
            // 后端就绪 启动心跳
            _heartBeat.start();
            // 唤醒发送队列补发积压消息
            unawaited(_startConsumeOutGoing());
            // 拉取离线消息
            Get.find<MessageController>().initMessagePage();
            return;
            // 收到后端任意消息 重置心跳计时器
          } else if (event.dto.msgType == MessageType.heartBeat) {
            // 心跳包直接返回 不进入消息总线单例
            _heartBeat.resetHeartBeat();
            return;
          } else if (event.dto.msgType == MessageType.ack) {
            ackHelper.onReciveAck(event.dto);
            return;
          }
          _heartBeat.resetHeartBeat();
          // 将消息推送给全局分发器
          unawaited(MessageDispatcher.instance.dispatch(event.dto));
        } else if (event is ErrorEvent) {
          debugPrint(
            "websocket 异常：${event.error} \n 剩余重连次数：$_availableReconnectCount \n 重连耗尽与否状态：${autoReconnectExhausted.value} \n 用户是否正在手动重连状态：${isManuallyReconnecting.value}",
          );
        }
      });
    }
    // 先订阅监听事件 再进行连接 否则状态更新为 connected 的时候无法捕获事件 心跳轮询会无法启动
    await _connector.connect(baseUrl, token);
  }

  // 外部主动调用 即 用户主动断开连接
  Future<void> disConnect() async {
    _waitReadyTimer?.cancel();
    backendReady.value = false;
    // 主动断开 禁止后续自动重连
    _allowReconnect = false;
    autoReconnectExhausted.value = false;
    isManuallyReconnecting.value = false;
    // 清除正在排队的重连任务
    _clearReconnectTimer();
    // 关闭连接之前先停止心跳 清理内部计时器
    _heartBeat.stop();
    await _connector.disConnect();
  }

  // 异常关闭通道 心跳死亡 连接异常使用 可重连
  Future<void> _forceCloseConnection() async {
    _waitReadyTimer?.cancel();
    backendReady.value = false;
    _heartBeat.stop();

    await _connector.forceCloseInternal();
  }

  // 应用自动重连
  void _reconnect() {
    // 不允许重连 或 已经在重连 则直接返回
    if (!_allowReconnect || _reconnectTimer != null) return;
    if (_availableReconnectCount <= 0) {
      _allowReconnect = false; // 耗尽次数 关闭自动重连
      autoReconnectExhausted.value = true; // 通知 UI 渲染手动重连入口
      isManuallyReconnecting.value = false; // 关闭手动重连
      return;
    }
    debugPrint("计划${_reconnectDelay.inSeconds}秒后尝试重连");

    _reconnectTimer = Timer(_reconnectDelay, () async {
      // 开启新一轮重连 清理旧的定时器
      _clearReconnectTimer();
      // 再次校验 中途手动断开则终止重连
      if (!_allowReconnect) {
        return;
      }
      //消耗一次重连次数
      _availableReconnectCount--;
      debugPrint("开始执行重连 剩余重连次数：$_availableReconnectCount");

      unawaited(connect(token));
      // 延时递增 仅 healthy 事件才会重置回2s
      _reconnectDelay *= 2;
      if (_reconnectDelay > _maxReconnectDelay) {
        _reconnectDelay = _maxReconnectDelay;
      }
    });
  }

  // 用户手动触发重连
  Future<void> manualReconnect() async {
    if (isManuallyReconnecting.value) return;
    isManuallyReconnecting.value = true;
    _availableReconnectCount = 5;
    autoReconnectExhausted.value = false;
    _reconnectDelay = const Duration(seconds: 1);

    // 取消正在运行的自动重连定时器，避免冲突
    _clearReconnectTimer();

    try {
      // 临时禁止自动重连，避免 forceCloseInternal 触发自动重连
      _allowReconnect = false;

      // 关键：如果已有连接或正在连接，先强制关闭旧连接
      // 否则 connect 会因"连接已存在"直接返回，导致 ready 超时死循环
      if (_connector.status == WebSocketStatus.connected ||
          _connector.status == WebSocketStatus.connecting) {
        await _connector.forceCloseInternal();
      }

      // connect 内部会设置 _allowReconnect = true
      await connect(token);
      // 不在此处重置 isManuallyReconnecting
      // 由心跳健康（连接成功）或重连耗尽（连接失败）时重置
    } catch (e, stack) {
      debugPrint("手动重连异常：$e\n$stack");
      isManuallyReconnecting.value = false;
    }
  }

  // 清理重连定时器
  void _clearReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // 消费者队列
  final _outGoingQueue = Queue<MessageDto>();
  // 是否正在消费 防并发
  bool _isConsuming = false;

  bool sendDto(MessageDto dto) {
    if (dto.msgType == MessageType.heartBeat) {
      return _connector.send(dto);
    }
    // 去重检查：如果相同 requestId 的消息已经在队列中，不重复加入
    final requestId = dto.requestId;
    if (requestId != null) {
      // 检查是否已在发送队列中
      final inQueue = _outGoingQueue.any((e) => e.requestId == requestId);
      if (inQueue) {
        debugPrint("消息：$requestId 已在发送队列中，不重复加入");
        return false;
      }
    }
    // 入队时即注册 ACK 监听（即使链路断开也会启动计时器）
    // 这样即使消息没被消费，也会超时→重试→流放，不会永远转圈
    if (requestId != null) ackHelper.addPendingId(dto);
    _outGoingQueue.add(dto);
    _startConsumeOutGoing();
    return true;
  }

  /// 从发送队列中移除指定 requestId 的消息，避免重发时重复发送
  void removeFromQueue(String? requestId) {
    if (requestId == null) return;
    _outGoingQueue.removeWhere((e) => e.requestId == requestId);
  }

  Future<void> _startConsumeOutGoing() async {
    if (_isConsuming) return;
    _isConsuming = true;
    bool consumedAny = false; // 记录本次是否真正消费过消息
    try {
      while (_outGoingQueue.isNotEmpty) {
        if (_connector.status != WebSocketStatus.connected ||
            !backendReady.value ||
            _heartBeat.currentHealth == ConnectionHealth.dead) {
          debugPrint("通道异常 / 后端未就绪 / 链路死亡，暂停发送，消息保留队列");
          debugPrint("消息保留，当前队列长度：${_outGoingQueue.length}");
          break;
        }

        final dto = _outGoingQueue.first;
        final requestId = dto.requestId;

        // 去重检查：如果消息已经真正发送过且正在等待ACK，跳过避免重复发送
        // sent=false 的消息（如刚入队或超时重试）允许继续发送
        if (requestId != null &&
            ackHelper.isSent(requestId) &&
            ackHelper.isRequestPending(requestId)) {
          debugPrint("消息：$requestId 已发送且等待ACK，跳过重复发送");
          _outGoingQueue.removeFirst();
          continue;
        }

        // 注册 ack 追踪（入队时已注册，这里处理 retry 状态的重置）
        ackHelper.addPendingId(dto);
        // 注册完毕正常情况下 是 pending  isRequestRoamed 结果为 false 可以继续发送
        // 若内部判定超过限次 则回删除该 dto 所注册的 key 此时 isRequestRoamed 结果为 true 不可继续发送
        bool isRoamed = false;
        if (requestId != null) {
          isRoamed = ackHelper.isRequestRoamed(requestId);
        }
        if (isRoamed) {
          _outGoingQueue.removeFirst();
          continue;
        }
        // 无论结果如何都要先出队
        // 失败 触发 AckHelper 的 failed 回调将存储中的 dto 回队
        // 成功 则已经出队 不再处理
        // 漫游 则已经存储在 AckHelper 的 漫游队列中
        _outGoingQueue.removeFirst();
        final ok = _connector.send(dto);
        if (!ok) {
          // send返回false 发送链路直接失败 但消息已经弹出队列
          // 将消息写回队列
          _outGoingQueue.add(dto);
          break;
        }
        // 标记消息已经真正发送过，避免重复发送
        ackHelper.markAsSent(requestId);
        consumedAny = true;
        await Future.delayed(const Duration(milliseconds: 30));
      }
    } finally {
      _isConsuming = false;
      // 只有本次真正消费过消息且队列还有剩余时，才触发下一轮
      // 避免链路异常 break 时无限递归
      if (consumedAny && _outGoingQueue.isNotEmpty) {
        unawaited(_startConsumeOutGoing());
      }
    }
  }

  void dispose() {
    _waitReadyTimer?.cancel();
    _clearReconnectTimer();
    _healthSub.cancel();
    _eventSub.cancel();
    _ackRespSub.cancel();
    ackHelper.dispose();
    _heartBeat.dispose();
    _connector.dispose();
  }
}
