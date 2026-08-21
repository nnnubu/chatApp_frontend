import 'dart:async';
import 'package:chatapp/dto/dto_message.dart';
import 'package:flutter/rendering.dart';

enum AckStatus {
  success, // 后端成功接收该消息
  failed, // 后端未能接收该消息
  roamed, // 后端多次未能接收该消息并被流放
  pending, // 正在等待后端回执
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
  final MessageDto dto;
  AckListener({
    required this.ackTimer,
    required this.dto, // 监听需要保存 dto 当失败时方便构建 AckResponse 回队 成功时也方便添加后端返回的字段信息
    this.status = AckStatus.pending,
    this.requestCount = 1,
  });
}

class AckHelper {
  late final StreamController<AckResponse> _ackRespStreamController;
  Stream<AckResponse> get ackRespStream => _ackRespStreamController.stream;

  AckHelper() {
    _ackRespStreamController = StreamController<AckResponse>();
  }
  // requestId -> 监听记录 timer 重试计数 原始dto
  final Map<String, AckListener> _pending = {};

  static const _ackTimeOut = Duration(seconds: 8);
  static const int maxRetryCount = 3;
  List<MessageDto> roamedMsgList = [];

  // 消息是否被流放
  bool isRequestRoamed(String requestId) {
    return !_pending.containsKey(requestId) &&
        roamedMsgList.any((e) => e.requestId == requestId);
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
      // 已经发送的次数 >= 最大允许重试次数 直接流放

      // 达到上限
      if (listener.requestCount >= maxRetryCount) {
        _pending.remove(requestId);
        listener.ackTimer.cancel();
        // 推入漫游列表 并推送 漫游事件通知
        roamedMsgList.add(dto);
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
      debugPrint(data["errMsg"]);
      return;
    }

    final AckListener listener = _pending.remove(requestId)!;
    listener.ackTimer.cancel();

    // 若后端传输回 msgId 则为消息添加 msgId 原本拥有和原本为空不影响
    listener.dto.msgId = dto.msgId;
    _ackRespStreamController.add(
      AckResponse(
        requestId: requestId,
        ackStatus: AckStatus.success,
        dto: listener.dto,
      ),
    );
    return;
  }

  // 等待超时则删除定时器，更新状态为 failed 并通知失败
  void onTimeOut(String requestId) {
    debugPrint("消息：$requestId 接收超时或失败");

    final AckListener listener = _pending[requestId]!;
    listener.ackTimer.cancel();
    listener.status = AckStatus.failed;
    _ackRespStreamController.add(
      AckResponse(
        requestId: requestId,
        ackStatus: AckStatus.failed,
        dto: listener.dto,
      ),
    );
  }

  void dispose() {
    _pending.forEach((_, value) {
      value.ackTimer.cancel();
    });
    _pending.clear();
    _ackRespStreamController.close();
  }
}
