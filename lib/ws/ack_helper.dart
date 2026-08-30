import 'dart:async';
import 'package:chatapp/dto/dto_message.dart';
import 'package:flutter/rendering.dart';

enum AckStatus {
  success, // 后端成功接收该消息
  failed, // 后端未能接收该消息（保留兼容，实际由 roamed 触发感叹号）
  roamed, // 后端多次未能接收该消息并被流放，显示感叹号
  pending, // 正在等待后端回执，显示转圈
  retry, // 内部状态：ACK超时，需要重新入队发送（不对外显示）
}

class AckResponse {
  final String requestId;
  final AckStatus ackStatus;
  final MessageDto? dto;
  AckResponse({required this.requestId, required this.ackStatus, this.dto});
}

class AckListener {
  Timer ackTimer;
  AckStatus status;
  int requestCount;
  bool sent; // 标记消息是否已经通过 WebSocket 真正发送过
  final MessageDto dto;
  AckListener({
    required this.ackTimer,
    required this.dto, // 监听需要保存 dto 当失败时方便构建 AckResponse 回队 成功时也方便添加后端返回的字段信息
    this.status = AckStatus.pending,
    this.requestCount = 1,
    this.sent = false,
  });
}

class AckHelper {
  late final StreamController<AckResponse> _ackRespStreamController;
  Stream<AckResponse> get ackRespStream => _ackRespStreamController.stream;

  AckHelper() {
    _ackRespStreamController = StreamController<AckResponse>.broadcast();
  }
  // requestId -> 监听记录 timer 重试计数 原始dto
  final Map<String, AckListener> _pending = {};

  static const _ackTimeOut = Duration(seconds: 8);
  static const int maxRetryCount = 3;
  // 流放队列最大长度，防止内存泄漏
  static const int _maxRoamedListSize = 50;
  List<MessageDto> roamedMsgList = [];

  // 消息是否被流放
  bool isRequestRoamed(String requestId) {
    return !_pending.containsKey(requestId) &&
        roamedMsgList.any((e) => e.requestId == requestId);
  }

  // 消息是否正在等待 ACK（pending 状态）
  bool isRequestPending(String requestId) {
    final listener = _pending[requestId];
    return listener != null && listener.status == AckStatus.pending;
  }

  // 消息是否已经通过 WebSocket 真正发送过
  bool isSent(String? requestId) {
    if (requestId == null) return false;
    final listener = _pending[requestId];
    return listener != null && listener.sent;
  }

  // 标记消息已经真正发送过
  void markAsSent(String? requestId) {
    if (requestId == null) return;
    final listener = _pending[requestId];
    if (listener != null) {
      listener.sent = true;
    }
  }

  void addPendingId(MessageDto dto) {
    final String? requestId = dto.requestId;
    if (requestId == null) {
      // 无requestId，不做ack追踪
      return;
    }

    if (_pending.containsKey(requestId)) {
      final listener = _pending[requestId]!;
      // 如果正在等待则返回 避免重复注册
      if (listener.status == AckStatus.pending) return;
      // 如果是自动重试中间态（retry），重置计时器但不重复计数
      // 计数已在 onTimeOut 中增加过了
      if (listener.status == AckStatus.retry) {
        listener.ackTimer.cancel();
        listener.ackTimer = Timer(_ackTimeOut, () {
          onTimeOut(requestId);
        });
        listener.status = AckStatus.pending;
        return;
      }
      // 已经发送的次数 >= 最大允许重试次数 直接流放

      // 达到上限
      if (listener.requestCount >= maxRetryCount) {
        _pending.remove(requestId);
        listener.ackTimer.cancel();
        // 推入漫游列表 并推送 漫游事件通知（带去重）
        _addToRoamedList(dto);
        AckResponse resp = AckResponse(
          requestId: requestId,
          ackStatus: AckStatus.roamed,
        );
        _ackRespStreamController.add(resp);
        return;
      }

      // 未超过最大重试次数
      // 重建新计时器 并增加计数
      listener.ackTimer.cancel();
      listener.ackTimer = Timer(_ackTimeOut, () {
        onTimeOut(requestId);
      });
      listener.status = AckStatus.pending;
      listener.requestCount++;
      return;
    }

    // 初次发送则注册新的监听
    _pending[requestId] = AckListener(
      ackTimer: Timer(_ackTimeOut, () {
        // 延迟执行超时 即等待后端 ack
        onTimeOut(requestId);
      }),
      dto: dto,
    );
  }

  /// 添加到流放队列，带去重和长度限制
  void _addToRoamedList(MessageDto dto) {
    // 去重：如果已经在流放列表中，不重复添加
    final exist = roamedMsgList.any((e) => e.requestId == dto.requestId);
    if (exist) return;
    roamedMsgList.add(dto);
    if (roamedMsgList.length > _maxRoamedListSize) {
      roamedMsgList.removeAt(0);
    }
  }

  /// 从流放队列移除，重发成功后调用
  void removeFromRoamedList(String? requestId) {
    if (requestId == null) return;
    roamedMsgList.removeWhere((e) => e.requestId == requestId);
  }

  void onReciveAck(MessageDto dto) {
    String? requestId = dto.requestId;
    if (requestId == null || !_pending.containsKey(requestId)) {
      // 后端需携带 requestId 若未携带则返回等待超时处理
      // 若当前等待列表没有该消息则返回 即后端传输了错误的消息包
      return;
    }

    Map<String, dynamic>? data = dto.data;
    // 后端未传输数据 或 未成功
    if (data == null) return;
    if (!data["success"]) {
      // 后端返回失败，推送失败事件，让前端显示感叹号
      final listener = _pending[requestId]!;
      listener.ackTimer.cancel();
      listener.status = AckStatus.failed;
      debugPrint("消息：$requestId 后端返回失败：${data["errMsg"]}");
      _ackRespStreamController.add(
        AckResponse(
          requestId: requestId,
          ackStatus: AckStatus.failed,
          dto: listener.dto,
        ),
      );
      return;
    }

    final AckListener listener = _pending.remove(requestId)!;
    listener.ackTimer.cancel();

    // 若后端传输回 msgId 则为消息添加 msgId 原本拥有和原本为空不影响
    listener.dto.msgId = dto.msgId;
    // 从流放队列移除（如果有的话）
    removeFromRoamedList(requestId);
    _ackRespStreamController.add(
      AckResponse(
        requestId: requestId,
        ackStatus: AckStatus.success,
        dto: listener.dto,
      ),
    );
    return;
  }

  // ACK 超时：自动重试，重试次数用尽后才流放
  void onTimeOut(String requestId) {
    final AckListener listener = _pending[requestId]!;
    listener.ackTimer.cancel();

    // 未达到最大重试次数：自动重试，继续显示转圈
    if (listener.requestCount < maxRetryCount) {
      listener.requestCount++;
      // 改为 retry 中间态：isRequestPending 返回 false，消息可以被重新消费发送
      listener.status = AckStatus.retry;
      listener.sent = false; // 重置发送标志，允许重新发送
      // 关键：在这里直接创建新计时器，不依赖 addPendingId
      // 因为连接不正常时 _startConsumeOutGoing 会直接 break，addPendingId 走不到
      listener.ackTimer = Timer(_ackTimeOut, () {
        onTimeOut(requestId);
      });
      debugPrint("消息：$requestId ACK超时，第${listener.requestCount}次自动重试");
      // 推送 retry 事件，通知 websocket_service 重新入队发送
      _ackRespStreamController.add(
        AckResponse(
          requestId: requestId,
          ackStatus: AckStatus.retry,
          dto: listener.dto,
        ),
      );
      return;
    }

    // 重试次数用尽，流放消息，显示感叹号
    debugPrint("消息：$requestId 重试$maxRetryCount次均失败，已流放");
    listener.status = AckStatus.roamed;
    _pending.remove(requestId);
    _addToRoamedList(listener.dto);
    _ackRespStreamController.add(
      AckResponse(
        requestId: requestId,
        ackStatus: AckStatus.roamed,
        dto: listener.dto,
      ),
    );
  }

  /// 用户手动重发时调用：从流放队列移除，重置重试计数，返回可重新发送的 dto
  MessageDto? resetForResend(String? requestId) {
    if (requestId == null) return null;
    // 从流放队列移除
    final idx = roamedMsgList.indexWhere((e) => e.requestId == requestId);
    if (idx < 0) return null;
    final dto = roamedMsgList.removeAt(idx);
    // 从 pending 中移除（如果有的话）
    _pending.remove(requestId);
    return dto;
  }

  void dispose() {
    _pending.forEach((_, value) {
      value.ackTimer.cancel();
    });
    _pending.clear();
    roamedMsgList.clear();
    _ackRespStreamController.close();
  }
}
