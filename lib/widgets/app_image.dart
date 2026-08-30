import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 统一的图片加载组件
/// 支持：加载中骨架屏、加载失败兜底、不同图片类型
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final AppImageType type;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.type = AppImageType.general,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;
    final url = imageUrl.isEmpty ? '' : buildStaticUrl(imageUrl);

    Widget placeholder = _buildPlaceholder(theme);
    Widget errorWidget = _buildErrorWidget(theme);

    if (url.isEmpty) {
      return _buildContainer(errorWidget, theme);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder;
        },
        errorBuilder: (context, error, stack) => errorWidget,
      ),
    );
  }

  Widget _buildContainer(Widget child, AppTheme theme) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    return SizedBox(width: width, height: height, child: child);
  }

  /// 加载中占位：骨架屏效果
  Widget _buildPlaceholder(AppTheme theme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  /// 加载失败兜底
  Widget _buildErrorWidget(AppTheme theme) {
    IconData icon;
    switch (type) {
      case AppImageType.avatar:
        icon = Icons.person;
        break;
      case AppImageType.cover:
        icon = Icons.photo_library_outlined;
        break;
      case AppImageType.background:
        icon = Icons.image_not_supported_outlined;
        break;
      case AppImageType.general:
        icon = Icons.broken_image_outlined;
        break;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.surfaceColor,
            theme.thirdColor.withOpacity(0.3),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: Icon(
        icon,
        size: type == AppImageType.avatar ? (width ?? 36) * 0.5 : 32,
        color: theme.hintTextColor.withOpacity(0.6),
      ),
    );
  }
}

enum AppImageType {
  avatar,      // 头像
  cover,       // 封面（书籍、音乐等）
  background,  // 背景图
  general,     // 通用图片
}
