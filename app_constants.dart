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

// ==================== 主题系统 ====================

// 主题类型
enum ThemeType {
  freshGreen,
  warmVintageT,
  darkTheme,
  oceanBlue,
  sakuraPink,
  midnightPurple,
  minimalWhite,
  sunsetOrange,
}

/// 应用主题抽象类
/// 原有 6 个颜色属性保留以兼容现有代码，新增语义化属性供新代码使用
abstract class AppTheme {
  // === 原有属性（保留兼容）===
  Color get backGroundColor;
  Color get secondColor;
  Color get thirdColor;
  Color get forthColor;
  Color get activeColor;
  Color get fontColor;

  // === 新增语义化颜色 ===
  Color get primaryColor;       // 主色（品牌色、按钮、强调）
  Color get secondaryColor;     // 辅色（次要按钮、标签）
  Color get scaffoldBg;         // 页面背景
  Color get surfaceColor;       // 卡片/面板背景
  Color get appBarColor;        // 顶栏/导航栏背景
  Color get inputBgColor;       // 输入框背景
  Color get dividerColor;       // 分割线
  Color get errorColor;         // 错误提示
  Color get hintTextColor;      // 提示文字
  Color get selfBubbleColor;    // 自己的消息气泡
  Color get otherBubbleColor;   // 对方的消息气泡

  // === 文字样式 ===
  TextStyle get titleStyle;     // 页面大标题
  TextStyle get headingStyle;   // 次级标题
  TextStyle get bodyStyle;      // 正文
  TextStyle get captionStyle;   // 辅助文字/时间戳
  TextStyle get buttonStyle;    // 按钮文字

  // === 圆角/间距常量 ===
  double get cardRadius;
  double get inputRadius;
  double get buttonRadius;
  double get bubbleRadius;
}

// ==================== 清新绿主题 ====================
class FreshGreenTheme implements AppTheme {
  // 原有兼容属性
  @override
  Color backGroundColor = const Color(0xFFE8F5F0);
  @override
  Color secondColor = const Color(0xFF7FD1B9);
  @override
  Color thirdColor = Colors.white;
  @override
  Color forthColor = Colors.grey.shade400;
  @override
  Color activeColor = const Color(0xFF2EB88C);
  @override
  Color fontColor = const Color(0xFF1A5C4A);

  // 语义化颜色
  @override
  Color primaryColor = const Color(0xFF2EB88C);
  @override
  Color secondaryColor = const Color(0xFF7FD1B9);
  @override
  Color scaffoldBg = const Color(0xFFE8F5F0);
  @override
  Color surfaceColor = Colors.white;
  @override
  Color appBarColor = const Color(0xFF7FD1B9);
  @override
  Color inputBgColor = Colors.white;
  @override
  Color dividerColor = const Color(0xFFD0E8DF);
  @override
  Color errorColor = const Color(0xFFE57373);
  @override
  Color hintTextColor = Colors.grey.shade500;
  @override
  Color selfBubbleColor = const Color(0xFF7FD1B9);
  @override
  Color otherBubbleColor = Colors.white;

  // 文字样式
  @override
  TextStyle titleStyle = const TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A5C4A),
  );
  @override
  TextStyle headingStyle = const TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A5C4A),
  );
  @override
  TextStyle bodyStyle = const TextStyle(
    fontSize: 15, color: Color(0xFF2D6B5A),
  );
  @override
  TextStyle captionStyle = TextStyle(
    fontSize: 12, color: Colors.grey.shade600,
  );
  @override
  TextStyle buttonStyle = const TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
  );

  // 圆角
  @override
  double cardRadius = 12;
  @override
  double inputRadius = 10;
  @override
  double buttonRadius = 10;
  @override
  double bubbleRadius = 16;
}

// ==================== 暖复古主题 ====================
class WarmVintageTheme implements AppTheme {
  // 原有兼容属性
  @override
  Color backGroundColor = const Color(0xFFF5EFE0);
  @override
  Color secondColor = const Color(0xFFD4B88E);
  @override
  Color thirdColor = const Color(0xFFFAF5E8);
  @override
  Color forthColor = Colors.brown.shade300;
  @override
  Color activeColor = const Color(0xFFC48B3C);
  @override
  Color fontColor = const Color(0xFF6B4423);

  // 语义化颜色
  @override
  Color primaryColor = const Color(0xFFC48B3C);
  @override
  Color secondaryColor = const Color(0xFFD4B88E);
  @override
  Color scaffoldBg = const Color(0xFFF5EFE0);
  @override
  Color surfaceColor = const Color(0xFFFAF5E8);
  @override
  Color appBarColor = const Color(0xFFD4B88E);
  @override
  Color inputBgColor = const Color(0xFFFAF5E8);
  @override
  Color dividerColor = const Color(0xFFE8DCC4);
  @override
  Color errorColor = const Color(0xFFC4704A);
  @override
  Color hintTextColor = Colors.brown.shade400;
  @override
  Color selfBubbleColor = const Color(0xFFD4B88E);
  @override
  Color otherBubbleColor = const Color(0xFFFAF5E8);

  // 文字样式
  @override
  TextStyle titleStyle = const TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B4423),
  );
  @override
  TextStyle headingStyle = const TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF6B4423),
  );
  @override
  TextStyle bodyStyle = const TextStyle(
    fontSize: 15, color: Color(0xFF7A5230),
  );
  @override
  TextStyle captionStyle = TextStyle(
    fontSize: 12, color: Colors.brown.shade500,
  );
  @override
  TextStyle buttonStyle = const TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A2E15),
  );

  // 圆角
  @override
  double cardRadius = 14;
  @override
  double inputRadius = 12;
  @override
  double buttonRadius = 12;
  @override
  double bubbleRadius = 18;
}

// ==================== 暗色主题 ====================
class DarkTheme implements AppTheme {
  // 原有兼容属性
  @override
  Color backGroundColor = const Color(0xFF1A1A1F);
  @override
  Color secondColor = const Color(0xFF2A2A32);
  @override
  Color thirdColor = const Color(0xFF3A3A44);
  @override
  Color forthColor = Colors.grey.shade600;
  @override
  Color activeColor = const Color(0xFF6C8EFF);
  @override
  Color fontColor = const Color(0xFFE0E0E8);

  // 语义化颜色
  @override
  Color primaryColor = const Color(0xFF6C8EFF);
  @override
  Color secondaryColor = const Color(0xFF4A5AA8);
  @override
  Color scaffoldBg = const Color(0xFF1A1A1F);
  @override
  Color surfaceColor = const Color(0xFF2A2A32);
  @override
  Color appBarColor = const Color(0xFF22222A);
  @override
  Color inputBgColor = const Color(0xFF2A2A32);
  @override
  Color dividerColor = const Color(0xFF3A3A44);
  @override
  Color errorColor = const Color(0xFFEF5350);
  @override
  Color hintTextColor = Colors.grey.shade500;
  @override
  Color selfBubbleColor = const Color(0xFF4A5AA8);
  @override
  Color otherBubbleColor = const Color(0xFF2A2A32);

  // 文字样式
  @override
  TextStyle titleStyle = const TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE0E0E8),
  );
  @override
  TextStyle headingStyle = const TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFE0E0E8),
  );
  @override
  TextStyle bodyStyle = const TextStyle(
    fontSize: 15, color: Color(0xFFC8C8D0),
  );
  @override
  TextStyle captionStyle = TextStyle(
    fontSize: 12, color: Colors.grey.shade500,
  );
  @override
  TextStyle buttonStyle = const TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
  );

  // 圆角
  @override
  double cardRadius = 12;
  @override
  double inputRadius = 10;
  @override
  double buttonRadius = 10;
  @override
  double bubbleRadius = 16;
}

// ==================== 深海蓝主题 ====================
class OceanBlueTheme implements AppTheme {
  @override
  Color backGroundColor = const Color(0xFF0A1628);
  @override
  Color secondColor = const Color(0xFF152238);
  @override
  Color thirdColor = const Color(0xFF1E3A5F);
  @override
  Color forthColor = Colors.blueGrey.shade600;
  @override
  Color activeColor = const Color(0xFF4FC3F7);
  @override
  Color fontColor = const Color(0xFFE0F0FF);
  @override
  Color primaryColor = const Color(0xFF4FC3F7);
  @override
  Color secondaryColor = const Color(0xFF0288D1);
  @override
  Color scaffoldBg = const Color(0xFF0A1628);
  @override
  Color surfaceColor = const Color(0xFF152238);
  @override
  Color appBarColor = const Color(0xFF0D1B2E);
  @override
  Color inputBgColor = const Color(0xFF1E3A5F);
  @override
  Color dividerColor = const Color(0xFF1E3A5F);
  @override
  Color errorColor = const Color(0xFFEF5350);
  @override
  Color hintTextColor = Colors.blueGrey.shade400;
  @override
  Color selfBubbleColor = const Color(0xFF0288D1);
  @override
  Color otherBubbleColor = const Color(0xFF1E3A5F);
  @override
  TextStyle titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE0F0FF));
  @override
  TextStyle headingStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFE0F0FF));
  @override
  TextStyle bodyStyle = const TextStyle(fontSize: 15, color: Color(0xFFB0D0F0));
  @override
  TextStyle captionStyle = TextStyle(fontSize: 12, color: Colors.blueGrey.shade400);
  @override
  TextStyle buttonStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0A1628));
  @override
  double cardRadius = 14;
  @override
  double inputRadius = 12;
  @override
  double buttonRadius = 12;
  @override
  double bubbleRadius = 18;
}

// ==================== 樱花粉主题 ====================
class SakuraPinkTheme implements AppTheme {
  @override
  Color backGroundColor = const Color(0xFFFFF0F5);
  @override
  Color secondColor = const Color(0xFFFFB6C1);
  @override
  Color thirdColor = Colors.white;
  @override
  Color forthColor = Colors.pink.shade300;
  @override
  Color activeColor = const Color(0xFFFF69B4);
  @override
  Color fontColor = const Color(0xFF8B4567);
  @override
  Color primaryColor = const Color(0xFFFF69B4);
  @override
  Color secondaryColor = const Color(0xFFFFB6C1);
  @override
  Color scaffoldBg = const Color(0xFFFFF0F5);
  @override
  Color surfaceColor = Colors.white;
  @override
  Color appBarColor = const Color(0xFFFFB6C1);
  @override
  Color inputBgColor = Colors.white;
  @override
  Color dividerColor = const Color(0xFFFFE0EC);
  @override
  Color errorColor = const Color(0xFFE57373);
  @override
  Color hintTextColor = Colors.pink.shade300;
  @override
  Color selfBubbleColor = const Color(0xFFFFB6C1);
  @override
  Color otherBubbleColor = Colors.white;
  @override
  TextStyle titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8B4567));
  @override
  TextStyle headingStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF8B4567));
  @override
  TextStyle bodyStyle = const TextStyle(fontSize: 15, color: Color(0xFFA05272));
  @override
  TextStyle captionStyle = TextStyle(fontSize: 12, color: Colors.pink.shade400);
  @override
  TextStyle buttonStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  @override
  double cardRadius = 16;
  @override
  double inputRadius = 14;
  @override
  double buttonRadius = 14;
  @override
  double bubbleRadius = 20;
}

// ==================== 暗夜紫主题 ====================
class MidnightPurpleTheme implements AppTheme {
  @override
  Color backGroundColor = const Color(0xFF1A0A2E);
  @override
  Color secondColor = const Color(0xFF2D1B4E);
  @override
  Color thirdColor = const Color(0xFF3D2A5C);
  @override
  Color forthColor = Colors.deepPurple.shade400;
  @override
  Color activeColor = const Color(0xFFBB86FC);
  @override
  Color fontColor = const Color(0xFFE8E0F0);
  @override
  Color primaryColor = const Color(0xFFBB86FC);
  @override
  Color secondaryColor = const Color(0xFF985EFF);
  @override
  Color scaffoldBg = const Color(0xFF1A0A2E);
  @override
  Color surfaceColor = const Color(0xFF2D1B4E);
  @override
  Color appBarColor = const Color(0xFF221040);
  @override
  Color inputBgColor = const Color(0xFF3D2A5C);
  @override
  Color dividerColor = const Color(0xFF3D2A5C);
  @override
  Color errorColor = const Color(0xFFCF6679);
  @override
  Color hintTextColor = Colors.deepPurple.shade300;
  @override
  Color selfBubbleColor = const Color(0xFF985EFF);
  @override
  Color otherBubbleColor = const Color(0xFF2D1B4E);
  @override
  TextStyle titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE8E0F0));
  @override
  TextStyle headingStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFE8E0F0));
  @override
  TextStyle bodyStyle = const TextStyle(fontSize: 15, color: Color(0xFFC8B8E0));
  @override
  TextStyle captionStyle = TextStyle(fontSize: 12, color: Colors.deepPurple.shade300);
  @override
  TextStyle buttonStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A0A2E));
  @override
  double cardRadius = 14;
  @override
  double inputRadius = 12;
  @override
  double buttonRadius = 12;
  @override
  double bubbleRadius = 18;
}

// ==================== 极简白主题 ====================
class MinimalWhiteTheme implements AppTheme {
  @override
  Color backGroundColor = const Color(0xFFFAFAFA);
  @override
  Color secondColor = Colors.white;
  @override
  Color thirdColor = const Color(0xFFF5F5F5);
  @override
  Color forthColor = Colors.grey.shade400;
  @override
  Color activeColor = const Color(0xFF212121);
  @override
  Color fontColor = const Color(0xFF212121);
  @override
  Color primaryColor = const Color(0xFF212121);
  @override
  Color secondaryColor = const Color(0xFF757575);
  @override
  Color scaffoldBg = const Color(0xFFFAFAFA);
  @override
  Color surfaceColor = Colors.white;
  @override
  Color appBarColor = Colors.white;
  @override
  Color inputBgColor = const Color(0xFFF5F5F5);
  @override
  Color dividerColor = const Color(0xFFE0E0E0);
  @override
  Color errorColor = const Color(0xFFE53935);
  @override
  Color hintTextColor = Colors.grey.shade500;
  @override
  Color selfBubbleColor = const Color(0xFF212121);
  @override
  Color otherBubbleColor = Colors.white;
  @override
  TextStyle titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF212121));
  @override
  TextStyle headingStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF212121));
  @override
  TextStyle bodyStyle = const TextStyle(fontSize: 15, color: Color(0xFF424242));
  @override
  TextStyle captionStyle = TextStyle(fontSize: 12, color: Colors.grey.shade500);
  @override
  TextStyle buttonStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  @override
  double cardRadius = 10;
  @override
  double inputRadius = 8;
  @override
  double buttonRadius = 8;
  @override
  double bubbleRadius = 14;
}

// ==================== 落日橙主题 ====================
class SunsetOrangeTheme implements AppTheme {
  @override
  Color backGroundColor = const Color(0xFFFFF3E0);
  @override
  Color secondColor = const Color(0xFFFFCC80);
  @override
  Color thirdColor = Colors.white;
  @override
  Color forthColor = Colors.orange.shade300;
  @override
  Color activeColor = const Color(0xFFFF6D00);
  @override
  Color fontColor = const Color(0xFFBF360C);
  @override
  Color primaryColor = const Color(0xFFFF6D00);
  @override
  Color secondaryColor = const Color(0xFFFFCC80);
  @override
  Color scaffoldBg = const Color(0xFFFFF3E0);
  @override
  Color surfaceColor = Colors.white;
  @override
  Color appBarColor = const Color(0xFFFFCC80);
  @override
  Color inputBgColor = Colors.white;
  @override
  Color dividerColor = const Color(0xFFFFE0B2);
  @override
  Color errorColor = const Color(0xFFE53935);
  @override
  Color hintTextColor = Colors.orange.shade400;
  @override
  Color selfBubbleColor = const Color(0xFFFFCC80);
  @override
  Color otherBubbleColor = Colors.white;
  @override
  TextStyle titleStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFBF360C));
  @override
  TextStyle headingStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFBF360C));
  @override
  TextStyle bodyStyle = const TextStyle(fontSize: 15, color: Color(0xFFE65100));
  @override
  TextStyle captionStyle = TextStyle(fontSize: 12, color: Colors.orange.shade500);
  @override
  TextStyle buttonStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  @override
  double cardRadius = 14;
  @override
  double inputRadius = 12;
  @override
  double buttonRadius = 12;
  @override
  double bubbleRadius = 18;
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
