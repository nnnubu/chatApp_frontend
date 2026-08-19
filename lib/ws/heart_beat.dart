import 'dart:async';
import 'package:flutter/material.dart';

enum ConnectionHealth {
  unconfirmed, // 刚启动心跳 未收到服务器响应
  healthy, // 收到服务端消息 判定通路正常
  dead, // 心跳丢失 判定连接死亡
}

class HeartBeat {
  late final StreamController<ConnectionHealth> _healthStreamController;

  Stream<ConnectionHealth> get healthStream => _healthStreamController.stream;
  // 上层监听事件流健康状态变化可进行被动执行

  ConnectionHealth _currentHealth = ConnectionHealth.unconfirmed;
  ConnectionHealth get currentHealth => _currentHealth;
  // 上层可主动问询健康状态来决定业务

  HeartBeat() {
    // 广播心跳状态
    _healthStreamController = StreamController<ConnectionHealth>.broadcast();
  }

  // 更新健康状态 状态变化则推送事件
  void _setHealth(ConnectionHealth state) {
    if (_currentHealth == state) return;
    _currentHealth = state;
    _healthStreamController.add(state);
  }

  // 异常死亡 清理资源
  void markDead() {
    stop();
    _setHealth(ConnectionHealth.dead);
    onConnectDead?.call();
  }

  // 心跳周期 10s
  static const _heartBeatInterval = Duration(seconds: 10);
  // 等待 pong 超时 6s
  static const _pongTimeOut = Duration(seconds: 6);
  // 连续丢失阈值
  static const _maxLost = 3;

  Timer? _heartTimer;
  Timer? _pongWaitTimer;
  int _lostPongCount = 0;

  // 外部回调 内部判断心跳超时 则外部关闭连接
  VoidCallback? onConnectDead;
  // 外部回调 由外部发送 ping 消息
  Future<bool> Function()? sendPingCallback;

  // 收到任意服务端消息 则重置 丢失统计 并 销毁 pong 等待计时器
  void resetHeartBeat() {
    _lostPongCount = 0;
    _pongWaitTimer?.cancel();

    // 收到后端消息 认定链路健康
    _setHealth(ConnectionHealth.healthy);
  }

  // 正常停止心跳 清理所有计时器
  void stop() {
    _heartTimer?.cancel();
    _pongWaitTimer?.cancel();
    _heartTimer = null;
    _pongWaitTimer = null;
    _lostPongCount = 0;
    // 上层主动关闭 不需要标记链路死亡
  }

  void start() {
    stop();
    // 重新启动心跳 重置链路为未确认状态
    _setHealth(ConnectionHealth.unconfirmed);

    // Timer.periodic 周期性定时器 每隔一段时间 重复执行回调 做 心跳轮询
    // 此类定时器 不会自动停止 需要手动 cancel
    _heartTimer = Timer.periodic(_heartBeatInterval, (_) async {
      final sendFunc = sendPingCallback;
      if (sendFunc == null) {
        stop();
        return;
      }

      bool sendSuccess = await sendFunc();
      if (!sendSuccess) {
        // ping 发送失败 认定连接已死亡
        // 静默断网的情况下 可能需要等待数分钟才会判定连接死亡 具体看 sendFunc 的实现
        markDead();
        return;
      }

      // ping 发送成功 不代表链路存活 只是代表消息进入通道
      // 因此需要一个 pong 定时器来判定连接存活与否 依靠收到服务器应答来判定链路健康
      // 此定时器在收到任意消息时会被销毁 不标记死亡

      _pongWaitTimer?.cancel();
      // Timer 一次性定时器 等待指定时长 只执行回调一次 自动 cancel
      _pongWaitTimer = Timer(_pongTimeOut, () {
        _lostPongCount++;
        if (_lostPongCount >= _maxLost) {
          // 单词轮询内超时未收到 pong 则标记死亡
          markDead();
        }
      });
    });
  }

  void dispose() {
    stop();
    onConnectDead = null;
    sendPingCallback = null;
    _healthStreamController.close();
  }
}
