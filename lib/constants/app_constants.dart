import 'dart:ui';

import 'package:chatapp/ws/message_handler/category_list/category_pull_handler.dart';
import 'package:chatapp/ws/message_handler/message_List/chat_handler.dart';
import 'package:chatapp/ws/message_handler/message_List/friend_apply_handler.dart';
import 'package:flutter/material.dart';

// websocket 消息类型 或 请求返回类型
enum MessageType {
  ready,
  heartBeat,
  addFriend,
  chat,
  refuse,
  argee,
  markRead,
  ack,
  pullCategory,
  nil,
}

extension MsgTypeExt on MessageType {
  double get actionWidth {
    const base = 80.0;
    switch (this) {
      case MessageType.addFriend:
        return base * 2;
      case MessageType.chat:
      case MessageType.refuse:
      default:
        return base;
    }
  }

  // 是否好友申请消息
  bool get isAddFriend => this == MessageType.addFriend;
  // 是否同意好友申请
  bool get isAgree => this == MessageType.argee;
  // 是否拒绝好友申请
  bool get isRefuse => this == MessageType.refuse;
}

// 主题类型
enum ThemeType { freshGreen, warmVintageT, test }

abstract class AppTheme {
  Color get backGroundColor;
  Color get secondColor;
  Color get thirdColor;
  Color get forthColor;
  Color get activeColor;
}

class FreshGreenTheme implements AppTheme {
  @override
  Color backGroundColor = const Color.fromARGB(255, 197, 245, 233);
  @override
  Color secondColor = const Color.fromARGB(255, 133, 216, 194);
  @override
  Color thirdColor = Colors.white60;
  @override
  Color forthColor = Colors.grey;
  @override
  Color activeColor = Colors.green;
}

class WarmVintageTheme implements AppTheme {
  @override
  Color secondColor = Color(0xFFD4B88E);
  @override
  Color backGroundColor = Color(0xFFF2E6D4);
  @override
  Color thirdColor = Colors.white70;
  @override
  Color forthColor = Colors.grey;
  @override
  Color activeColor = Color.fromARGB(255, 212, 159, 80);
}

class Test implements AppTheme {
  @override
  Color backGroundColor = Color.fromARGB(255, 240, 117, 117);
  @override
  Color secondColor = Color.fromARGB(255, 248, 78, 26);
  @override
  Color thirdColor = Colors.white70;
  @override
  Color forthColor = Colors.grey;
  @override
  Color activeColor = Color.fromARGB(255, 236, 123, 79);
}

class AppBase {
  static const double iconSize = 25;
  static const double topBarHeight = 45;
  static const double menuIconWidth = 50;
  static const double topSlideHeight = 80;
  static const double waveUnderContentSize = 30;
  static const double waveUpperContentSize = 20;

  static const double bgImgHeight = 500;

  static const double popBoxWidthRatio = 0.8;
  static const double popBoxVerticalPadding = 10;
  static const double popBoxHorizontalPadding = 10;
  static const double popBoxRadius = 10;
  static const double popCloseIconSize = 30;

  static const double messageCardItemHeight = 60;
  static const double messageCardAvatarRadius = 50;
  static const double messageCardActionWidth = 80;

  static const Color onlineSign = Color.fromARGB(255, 12, 240, 23);
  static const double onlineRadius = 15;

  static const double chatCardItemHeight = 70;
}

class DeviceSize {
  // 全局唯一静态实例，外部只能访问这个 调用该实例自动执行私有构造_internal
  static final DeviceSize instance = DeviceSize._internal();
  // 私有命名构造函数，加下划线 _internal 外部无法 new 创建对象
  DeviceSize._internal();

  // 获取状态栏高度 dp
  double get statusBarHeight {
    // 获取当前设备所有渲染窗口
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    // 取主屏幕窗口
    final FlutterView view = views.first;
    // 从底层窗口读取系统安全区，单位是硬件 px，即为物理像素
    final ViewPadding pxPadding = view.viewPadding;
    // 获取当前屏幕的像素缩放倍率
    final double ratio = view.devicePixelRatio;
    // 物理像素 ÷ 像素比 = Flutter布局用的 dp(逻辑像素) 单位
    // EdgeInsets、padding 用的都是 逻辑像素
    return pxPadding.top / ratio;
  }

  // 获取底部手势条高度 dp
  double get bottomGestureHeight {
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    final FlutterView view = views.first;
    final ViewPadding pxPadding = view.viewPadding;
    final double ratio = view.devicePixelRatio;
    return pxPadding.bottom / ratio;
  }
}

final DefaultMessageHandlers = [FriendApplyHandler(),CategoryPullHandler(),ChatHandler()];