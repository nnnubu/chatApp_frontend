import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/book_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/dto/dto_book.dart';
import 'package:chatapp/service/book_service.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookDetailPage extends StatefulWidget {
  final String? bookUid;
  const BookDetailPage({super.key, this.bookUid});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late final ThemeController _themeController;
  late final BookController _bookController;
  late final String _bookUid;
  final Rxn<BookInfo> _book = Rxn<BookInfo>();
  final Rxn<ShelfBook> _shelfBook = Rxn<ShelfBook>();
  final RxBool _loading = true.obs;
  final RxDouble _rating = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
    _bookController = Get.find<BookController>();
    _bookUid = widget.bookUid ?? Get.arguments as String? ?? '';
    if (_bookUid.isEmpty) {
      _loading.value = false;
      return;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await BookService.bookDetail(_bookUid);
    if (result.isSuccess && result.data is BookInfo) {
      _book.value = result.data as BookInfo;
      // 检查是否在书架
      final idx = _bookController.shelf.indexWhere(
        (e) => e.book.bookUid == _bookUid,
      );
      if (idx >= 0) {
        _shelfBook.value = _bookController.shelf[idx];
        _rating.value = _shelfBook.value!.rating.toDouble();
      }
    }
    _loading.value = false;
  }

  Future<void> _addToShelf(int status) async {
    final success = await _bookController.addToShelf(_bookUid, status: status);
    if (success) {
      _loadDetail();
      Get.snackbar('成功', '已添加到书架', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _updateStatus(int status) async {
    await BookService.addToShelf(_bookUid, status: status);
    await _bookController.refreshShelf();
    _loadDetail();
  }

  Future<void> _updateRating(double rating) async {
    _rating.value = rating;
    await BookService.updateRating(_bookUid, rating.toInt());
    await _bookController.refreshShelf();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      final loading = _loading.value;
      final book = _book.value;
      final shelfBook = _shelfBook.value;
      final rating = _rating.value;

      return Scaffold(
        backgroundColor: t.scaffoldBg,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : book == null
                ? Center(child: Text('图书不存在', style: t.bodyStyle))
                : CustomScrollView(
                    slivers: [
                      // 顶部封面
                      SliverAppBar(
                        expandedHeight: 280,
                        pinned: true,
                        backgroundColor: t.appBarColor,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              book.cover.isNotEmpty
                                  ? Image.network(
                                      buildStaticUrl(book.cover),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: t.thirdColor,
                                        child: Icon(Icons.menu_book,
                                            size: 64, color: t.hintTextColor),
                                      ),
                                    )
                                  : Container(
                                      color: t.thirdColor,
                                      child: Icon(Icons.menu_book,
                                          size: 64, color: t.hintTextColor),
                                    ),
                              // 渐变遮罩
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 书名
                              Text(
                                book.title,
                                style: t.headingStyle.copyWith(fontSize: 22),
                              ),
                              const SizedBox(height: 8),
                              // 作者
                              Text(
                                book.author.isNotEmpty ? book.author : '未知作者',
                                style: t.captionStyle.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              // 分类标签
                              if (book.category.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: t.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    book.category,
                                    style: t.captionStyle.copyWith(
                                      color: t.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // 出版信息
                              if (book.publisher.isNotEmpty ||
                                  book.publishDate.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: t.surfaceColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      if (book.publisher.isNotEmpty)
                                        Expanded(
                                          child: _infoItem('出版社', book.publisher),
                                        ),
                                      if (book.publishDate.isNotEmpty)
                                        Expanded(
                                          child: _infoItem('出版日期', book.publishDate),
                                        ),
                                      if (book.totalPages > 0)
                                        Expanded(
                                          child: _infoItem(
                                              '页数', '${book.totalPages}页'),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              // 简介
                              Text('内容简介',
                                  style: t.headingStyle.copyWith(fontSize: 16)),
                              const SizedBox(height: 8),
                              Text(
                                book.intro.isNotEmpty ? book.intro : '暂无简介',
                                style: t.bodyStyle.copyWith(
                                  height: 1.6,
                                  color: t.fontColor.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 评分
                              if (shelfBook != null) ...[
                                Text('我的评分',
                                    style: t.headingStyle.copyWith(fontSize: 16)),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(5, (i) {
                                    return GestureDetector(
                                      onTap: () => _updateRating((i + 1).toDouble()),
                                      child: Icon(
                                        i < rating ? Icons.star : Icons.star_border,
                                        color: i < rating
                                            ? Colors.amber
                                            : t.hintTextColor,
                                        size: 32,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                // 阅读进度
                                if (shelfBook.status == 2 &&
                                    book.totalPages > 0) ...[
                                  Text('阅读进度',
                                      style: t.headingStyle.copyWith(fontSize: 16)),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: shelfBook.progress,
                                    backgroundColor: t.dividerColor,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        t.primaryColor),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${shelfBook.currentPage} / ${book.totalPages} 页 (${(shelfBook.progress * 100).toStringAsFixed(0)}%)',
                                    style: t.captionStyle,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        // 底部操作栏
        bottomNavigationBar: loading || book == null
            ? null
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: shelfBook == null
                      ? Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                '加入想读',
                                Icons.favorite_border,
                                () => _addToShelf(1),
                                t,
                                outlined: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                '开始阅读',
                                Icons.menu_book,
                                () => _addToShelf(2),
                                t,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                shelfBook.status == 2 ? '继续阅读' : '开始阅读',
                                Icons.play_arrow,
                                () => _updateStatus(2),
                                t,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                '标记已读',
                                Icons.check,
                                () => _updateStatus(3),
                                t,
                                outlined: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () async {
                                await _bookController.removeFromShelf(_bookUid);
                                Get.back();
                              },
                              icon: Icon(Icons.delete_outline, color: t.errorColor),
                            ),
                          ],
                        ),
                ),
              ),
      );
    });
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: _themeController.currentTheme.captionStyle.copyWith(
                  fontSize: 11,
                )),
        const SizedBox(height: 2),
        Text(value,
            style: _themeController.currentTheme.bodyStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
      ],
    );
  }

  Widget _actionButton(
      String label, IconData icon, VoidCallback onTap, AppTheme t,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : t.primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: outlined
              ? Border.all(color: t.primaryColor, width: 1.5)
              : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: t.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20, color: outlined ? t.primaryColor : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: outlined ? t.primaryColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
