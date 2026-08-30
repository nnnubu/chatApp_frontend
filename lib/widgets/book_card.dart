import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/dto/dto_book.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 图书卡片 - 用于推荐/搜索列表
class BookCard extends StatelessWidget {
  final BookInfo? book;
  final VoidCallback? onTap;
  final bool showProgress;
  final ShelfBook? shelfBook;

  const BookCard({
    super.key,
    this.book,
    this.onTap,
    this.showProgress = false,
    this.shelfBook,
  });

  @override
  Widget build(BuildContext context) {
    final progress = shelfBook?.progress ?? 0;
    final bookInfo = book ?? shelfBook?.book;
    final title = bookInfo?.title ?? '未命名';
    final author = bookInfo?.author ?? '';
    final cover = bookInfo?.cover ?? '';
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      themeController.currentType; // 触发响应式追踪
      final AppTheme t = themeController.currentTheme;
      return GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: cover.isNotEmpty
                            ? Image.network(
                                buildStaticUrl(cover),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholderCover(t),
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: t.thirdColor,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _placeholderCover(t),
                      ),
                      // 状态标签
                      if (shelfBook != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(shelfBook!.status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              shelfBook!.statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // 阅读进度条
                      if (showProgress && shelfBook != null && shelfBook!.currentPage > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.black26,
                            valueColor: AlwaysStoppedAnimation<Color>(t.primaryColor),
                            minHeight: 3,
                          ),
                        ),
                    ],
                  ),
                ),
                // 信息区
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.surfaceColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: t.bodyStyle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author.isNotEmpty ? author : '未知作者',
                        style: t.captionStyle.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _placeholderCover(AppTheme t) {
    return Container(
      color: t.thirdColor,
      child: Icon(Icons.menu_book, color: t.hintTextColor, size: 32),
    );
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return Colors.grey[600]!;
      case 2:
        return Colors.blue[600]!;
      case 3:
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
