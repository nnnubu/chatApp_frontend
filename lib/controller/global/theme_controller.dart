import 'package:chatapp/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _storageKey = 'app_theme_type';

  // 响应式存储当前选中的主题类型
  final Rx<ThemeType> _currentThemeType = ThemeType.darkTheme.obs;

  // 对外暴露当前生效的主题实例，页面可以直接取色
  AppTheme get currentTheme {
    switch (_currentThemeType.value) {
      case ThemeType.freshGreen:
        return FreshGreenTheme();
      case ThemeType.warmVintageT:
        return WarmVintageTheme();
      case ThemeType.darkTheme:
        return DarkTheme();
      case ThemeType.oceanBlue:
        return OceanBlueTheme();
      case ThemeType.sakuraPink:
        return SakuraPinkTheme();
      case ThemeType.midnightPurple:
        return MidnightPurpleTheme();
      case ThemeType.minimalWhite:
        return MinimalWhiteTheme();
      case ThemeType.sunsetOrange:
        return SunsetOrangeTheme();
    }
  }

  ThemeType get currentType => _currentThemeType.value;

  /// 是否为暗色主题（用于系统状态栏图标颜色等）
  bool get isDark {
    switch (_currentThemeType.value) {
      case ThemeType.darkTheme:
      case ThemeType.oceanBlue:
      case ThemeType.midnightPurple:
        return true;
      default:
        return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  /// 从本地存储加载主题偏好
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        final type = ThemeType.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ThemeType.darkTheme,
        );
        _currentThemeType.value = type;
      }
    } catch (_) {
      // 读取失败静默使用默认主题
    }
  }

  /// 切换主题并持久化
  void switchTheme(ThemeType type) {
    if (_currentThemeType.value == type) return;
    _currentThemeType.value = type;
    _saveToStorage(type);
  }

  Future<void> _saveToStorage(ThemeType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, type.name);
    } catch (_) {
      // 持久化失败不影响运行
    }
  }

  /// 基于当前 AppTheme 生成 Flutter ThemeData
  /// 这样可以直接传给 GetMaterialApp 的 theme 属性
  ThemeData get themeData {
    final t = currentTheme;
    final isDark = this.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: t.scaffoldBg,
      primaryColor: t.primaryColor,

      // AppBar 主题
      appBarTheme: AppBarTheme(
        backgroundColor: t.appBarColor,
        foregroundColor: t.fontColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: t.headingStyle,
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: t.surfaceColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.inputBgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.inputRadius),
          borderSide: BorderSide(color: t.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.inputRadius),
          borderSide: BorderSide(color: t.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.inputRadius),
          borderSide: BorderSide(color: t.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.inputRadius),
          borderSide: BorderSide(color: t.errorColor),
        ),
        hintStyle: TextStyle(color: t.hintTextColor),
        labelStyle: TextStyle(color: t.hintTextColor),
      ),

      //  elevated button 主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primaryColor,
          foregroundColor: isDark ? Colors.white : t.fontColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.buttonRadius),
          ),
          textStyle: t.buttonStyle,
          elevation: 0,
        ),
      ),

      // 文字按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primaryColor,
        ),
      ),

      // 分割线主题
      dividerTheme: DividerThemeData(
        color: t.dividerColor,
        thickness: 0.5,
        space: 0,
      ),

      // 文字主题
      textTheme: TextTheme(
        headlineLarge: t.titleStyle,
        headlineMedium: t.headingStyle,
        bodyLarge: t.bodyStyle,
        bodyMedium: t.bodyStyle,
        bodySmall: t.captionStyle,
        labelLarge: t.buttonStyle,
      ),

      // 图标主题
      iconTheme: IconThemeData(color: t.fontColor),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.surfaceColor,
        selectedItemColor: t.primaryColor,
        unselectedItemColor: t.hintTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),

      // 浮动按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primaryColor,
        foregroundColor: Colors.white,
      ),

      // 统一页面过渡动画：淡入 + 轻微缩放
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeScalePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeScalePageTransitionsBuilder(),
          TargetPlatform.windows: _FadeScalePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeScalePageTransitionsBuilder(),
          TargetPlatform.linux: _FadeScalePageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 自定义页面过渡：淡入 + 从 0.98 缩放到 1.0
class _FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
        ),
        child: child,
      ),
    );
  }
}
