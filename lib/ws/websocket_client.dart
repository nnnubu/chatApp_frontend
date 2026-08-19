import 'dart:async';
import 'dart:convert';

import 'package:chatapp/dto/dto_message.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

// TCP 是面向连接的协议，一旦网络中断触发内核重传超时，这条 TCP 套接字就会被系统标记为 永久失效，哪怕重新连上 WiFi / 流量，旧套接字也无法恢复通信，有两点关键原因：

// 1. IP / 端口环境大概率变化
// 手机切换网络（WiFi ↔ 移动数据）时，设备的内网 IP、运营商出口公网 IP 全部改变；旧 TCP 连接绑定的是断网前的 IP 地址，IP 变了之后，旧通道的路由完全失效，操作系统不会自动复用旧套接字。
// 2. 内核 TCP 重传机制只会 “重试”，不会 “自愈”
// 断网的几十秒内，系统内核会反复重传待发送的数据包，但这只是短暂缓冲；
// 等重传计时器耗尽（手机普遍 30~90 秒），内核直接丢弃整条 TCP 连接的所有缓存，标记连接死亡。
// 此时再打开网络，旧套接字已经被内核废弃，Flutter 上层`_channel`不会自动重建 TCP，程序依旧拿着失效的旧通道发消息，数据包全部石沉大海，后端完全收不到。

// 因此 不可依赖操作系统抛出底层IO异常或是后端主动发送关闭帧 才执行重连操作
// 而是要进行 心跳主动监测，验证连接可用性  前端借此可以重新上线 后端借此也能更安全的清理内存

enum WebSocketStatus {
  idle, // 空闲 为建立连接
  connecting, // 正在连接
  connected, // 正常连通
  closed, // 正常关闭
  error, // 异常断开
}

// WebSocket 向外抛出的事件
abstract class WebSocketEvent {}

// 连接状态变更
class StatusChange extends WebSocketEvent {
  final WebSocketStatus status;
  StatusChange(this.status);
}

// 收到后端消息
class MessageEvent extends WebSocketEvent {
  final MessageDto dto;
  MessageEvent(this.dto);
}

// 连接发生错误
class ErrorEvent extends WebSocketEvent {
  final Object error;
  ErrorEvent(this.error);
}

class WebsocketConnector {
  // 广播消息流
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  IOWebSocketChannel? _channel;
  // 存储监听订阅
  StreamSubscription? _sub;
  WebSocketStatus _status = WebSocketStatus.idle;
  WebSocketStatus get status => _status;

  // 发起连接
  Future<void> connect(String url, String token) async {
    debugPrint("WebsocketConnector.connect 当前status: $_status");
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected) {
      debugPrint("连接已存在或正在连接");
      return;
    }

    _updateStatus(WebSocketStatus.connecting);
    try {
      debugPrint("正在建立连接 ${DateTime.now()}");
      // IOWebSocketChannel.connect() 是 同步方法
      // 仅在内存创建通道对象、发起TCP连接请求，函数立即返回
      // 不会阻塞等待 WebSocket 握手 HTTP 101 Switching Protocols 成功
      // 仅仅代表 发起连接 不代表和服务端握手协商完成
      // 极端场景 token错误、服务器拒绝、网络不通，此代码依旧正常返回对象
      // 真实握手成功/失败只能通过 stream 的 onDone / onError 感知，此处无返回值告知握手结果。
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );
      // 监听后端推送的消息
      _sub = _channel!.stream.listen(
        (rawData) {
          // rawData 即为 后端 WriteMessage 的两个参数 messageType 和 data 中的 data
          try {
            final map = json.decode(rawData);
            final dto = MessageDto.formJson(map);
            _eventController.add(MessageEvent(dto));
          } catch (e) {
            _eventController.add(ErrorEvent(e));
          }
        },
        // TCP 明确抛出异常触发
        onError: (err) {
          _eventController.add(ErrorEvent(err));
          _updateStatus(WebSocketStatus.error);
          _cleanResource();
        },
        // 后端主动发关闭帧触发
        onDone: () {
          // 通道主动关闭
          _updateStatus(WebSocketStatus.closed);
          _cleanResource();
        },
      );

      // 虽说无法判断是否握手成功 但还是先标记为已经连接
      // 为后面的心跳轮询开启提供条件
      // 若心跳轮询发送消息失败 则会调用关闭连接的方法进行处理
      _updateStatus(WebSocketStatus.connected);
    } catch (e) {
      _eventController.add(ErrorEvent(e));
      _updateStatus(WebSocketStatus.error);
      _cleanResource();
    }
  }

  // sendMessage 前端给后端推送消息
  // 返回 true：预检通过 消息成功加入本地发送缓冲区 但不代表后端收到消息！半僵死网络依旧可能丢包
  // 如需确认后端接收，聊天消息必须使用 ACK 超时机制
  bool send(MessageDto dto) {
    // closeCode 只有收到标准 WebSocket 关闭帧（规范挥手：服务端主动发关闭包）才会赋值 僵死连接永远是 null
    if (_status != WebSocketStatus.connected || _channel == null) {
      debugPrint("消息发送异常，请检查连接");
      return false;
    }
    try {
      // 静默断链（无任何关闭包）
      // 用户切换 Wi-Fi / 移动网络
      // 中间防火墙、NAT 网关超时回收 TCP 会话
      // 服务端进程被 kill、服务器宕机，没有机会发送关闭帧

      // 以上的情况下 若 TCP 内核缓冲区还有空余空间 此处不会触发异常
      // 但数据包无法发送给服务器 无法判定链路死亡
      // 当 TCP 重传耗尽 超时失败 再调用 add 才会触发异常 判定链路死亡
      final str = json.encode(dto.toJson());
      _channel!.sink.add(str);
      return true;
    } catch (e) {
      _eventController.add(ErrorEvent(e));
      return false;
    }
  }

  // 主动断开连接
  Future<void> disConnect() async {
    debugPrint("正在主动解除连接");
    await _cleanResource();
    _updateStatus(WebSocketStatus.idle);
  }

  // 异常断开连接 ready超时 心跳死亡
  Future<void> forceCloseInternal() async {
    debugPrint("异常解除连接");
    await _cleanResource();
    _updateStatus(WebSocketStatus.error);
  }

  // 更新状态
  void _updateStatus(WebSocketStatus s) {
    _status = s;
    _eventController.add(StatusChange(s));
  }

  Future<void> _cleanResource() async {
    // 先取消 stream 订阅 再发送关闭帧
    await _sub?.cancel();
    _sub = null;
    // sink.close() 返回 Future，await 保证关闭帧优先发出
    // 仅代表本地写入关闭帧成功 无法确认服务端收到关闭包
    if (_channel != null) {
      try {
        // 握手未完成场景下 sink.close 会无限挂起 因此设计超时跳出挂起
        await _channel?.sink.close().timeout(const Duration(milliseconds: 300));
      } on TimeoutException {
        debugPrint("sink.close() 超时挂起，放弃等待");
      } catch (e) {
        debugPrint("sink.close 异常 $e");
      }
    }
    _channel = null;
    debugPrint("已清理资源 ${DateTime.now()}");
  }

  // app 退出 或 模块销毁 时调用
  void dispose() {
    _eventController.close();
  }
}
