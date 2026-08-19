import 'package:chatapp/constants/app_constants.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  // 响应式存储当前选中的主题类型
  final Rx<ThemeType> _currentThemeType = ThemeType.freshGreen.obs;

  // 对外暴露当前生效的主题实例，页面可以直接取色
  AppTheme get currentTheme {
    switch (_currentThemeType.value) {
      case ThemeType.freshGreen:
        return FreshGreenTheme();
      case ThemeType.warmVintageT:
        return WarmVintageTheme();
      case ThemeType.test:
        return Test();
      default:
        return FreshGreenTheme();
    }
  }

  void switchTheme(ThemeType type) {
    _currentThemeType.value = type;
  }

  ThemeType get currentType => _currentThemeType.value;
}