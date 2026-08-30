import 'dart:async';
import 'package:flutter/material.dart';

enum ConnectionHealth {
  unconfirmed, // 鍒氬惎鍔ㄥ績璺?鏈敹鍒版湇鍔″櫒鍝嶅簲
  healthy, // 鏀跺埌鏈嶅姟绔秷鎭?鍒ゅ畾閫氳矾姝ｅ父
  dead, // 蹇冭烦涓㈠け 鍒ゅ畾杩炴帴姝讳骸
}

class HeartBeat {
  late final StreamController<ConnectionHealth> _healthStreamController;

  Stream<ConnectionHealth> get healthStream => _healthStreamController.stream;
  // 涓婂眰鐩戝惉浜嬩欢娴佸仴搴风姸鎬佸彉鍖栧彲杩涜琚姩鎵ц

  ConnectionHealth _currentHealth = ConnectionHealth.unconfirmed;
  ConnectionHealth get currentHealth => _currentHealth;
  // 涓婂眰鍙富鍔ㄩ棶璇㈠仴搴风姸鎬佹潵鍐冲畾涓氬姟

  HeartBeat() {
    // 骞挎挱蹇冭烦鐘舵€?
    _healthStreamController = StreamController<ConnectionHealth>.broadcast();
  }

  // 鏇存柊鍋ュ悍鐘舵€?鐘舵€佸彉鍖栧垯鎺ㄩ€佷簨浠?
  void _setHealth(ConnectionHealth state) {
    if (_currentHealth == state) return;
    _currentHealth = state;
    _healthStreamController.add(state);
  }

  // 寮傚父姝讳骸 娓呯悊璧勬簮
  void markDead() {
    stop();
    _setHealth(ConnectionHealth.dead);
    onConnectDead?.call();
  }

  // 心跳周期 5s（网络切换时更快检测死亡）
  static const _heartBeatInterval = Duration(seconds: 5);
  // 等待 pong 超时 3s
  static const _pongTimeOut = Duration(seconds: 3);
  // 连续丢失阈值 2 次
  static const _maxLost = 2;

  Timer? _heartTimer;
  Timer? _pongWaitTimer;
  int _lostPongCount = 0;

  // 澶栭儴鍥炶皟 鍐呴儴鍒ゆ柇蹇冭烦瓒呮椂 鍒欏閮ㄥ叧闂繛鎺?
  VoidCallback? onConnectDead;
  // 澶栭儴鍥炶皟 鐢卞閮ㄥ彂閫?ping 娑堟伅
  Future<bool> Function()? sendPingCallback;

  // 鏀跺埌浠绘剰鏈嶅姟绔秷鎭?鍒欓噸缃?涓㈠け缁熻 骞?閿€姣?pong 绛夊緟璁℃椂鍣?
  void resetHeartBeat() {
    _lostPongCount = 0;
    _pongWaitTimer?.cancel();

    // 鏀跺埌鍚庣娑堟伅 璁ゅ畾閾捐矾鍋ュ悍
    _setHealth(ConnectionHealth.healthy);
  }

  // 姝ｅ父鍋滄蹇冭烦 娓呯悊鎵€鏈夎鏃跺櫒
  void stop() {
    _heartTimer?.cancel();
    _pongWaitTimer?.cancel();
    _heartTimer = null;
    _pongWaitTimer = null;
    _lostPongCount = 0;
    // 涓婂眰涓诲姩鍏抽棴 涓嶉渶瑕佹爣璁伴摼璺浜?
  }

  void start() {
    stop();
    // 閲嶆柊鍚姩蹇冭烦 閲嶇疆閾捐矾涓烘湭纭鐘舵€?
    _setHealth(ConnectionHealth.unconfirmed);

    // Timer.periodic 鍛ㄦ湡鎬у畾鏃跺櫒 姣忛殧涓€娈垫椂闂?閲嶅鎵ц鍥炶皟 鍋?蹇冭烦杞
    // 姝ょ被瀹氭椂鍣?涓嶄細鑷姩鍋滄 闇€瑕佹墜鍔?cancel
    _heartTimer = Timer.periodic(_heartBeatInterval, (_) async {
      final sendFunc = sendPingCallback;
      if (sendFunc == null) {
        stop();
        return;
      }

      bool sendSuccess = await sendFunc();
      if (!sendSuccess) {
        // ping 鍙戦€佸け璐?璁ゅ畾杩炴帴宸叉浜?
        // 闈欓粯鏂綉鐨勬儏鍐典笅 鍙兘闇€瑕佺瓑寰呮暟鍒嗛挓鎵嶄細鍒ゅ畾杩炴帴姝讳骸 鍏蜂綋鐪?sendFunc 鐨勫疄鐜?
        markDead();
        return;
      }

      // ping 鍙戦€佹垚鍔?涓嶄唬琛ㄩ摼璺瓨娲?鍙槸浠ｈ〃娑堟伅杩涘叆閫氶亾
      // 鍥犳闇€瑕佷竴涓?pong 瀹氭椂鍣ㄦ潵鍒ゅ畾杩炴帴瀛樻椿涓庡惁 渚濋潬鏀跺埌鏈嶅姟鍣ㄥ簲绛旀潵鍒ゅ畾閾捐矾鍋ュ悍
      // 姝ゅ畾鏃跺櫒鍦ㄦ敹鍒颁换鎰忔秷鎭椂浼氳閿€姣?涓嶆爣璁版浜?

      _pongWaitTimer?.cancel();
      // Timer 涓€娆℃€у畾鏃跺櫒 绛夊緟鎸囧畾鏃堕暱 鍙墽琛屽洖璋冧竴娆?鑷姩 cancel
      _pongWaitTimer = Timer(_pongTimeOut, () {
        _lostPongCount++;
        if (_lostPongCount >= _maxLost) {
          // 鍗曡瘝杞鍐呰秴鏃舵湭鏀跺埌 pong 鍒欐爣璁版浜?
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
