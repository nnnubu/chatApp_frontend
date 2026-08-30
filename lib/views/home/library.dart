import 'dart:async';
import 'dart:ui';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/book_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/pages/book_detail.dart';
import 'package:chatapp/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<StatefulWidget> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with AutomaticKeepAliveClientMixin {
  late final ThemeController _themeController;
  late final BookController _bookController;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RxInt _currentTab = 0.obs; // 0: 推荐 1: 书架
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
    _bookController = Get.find<BookController>();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (_currentTab.value == 0) {
        _bookController.loadMoreBooks();
      } else {
        _bookController.loadMoreShelf();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    final FlutterView view = views.first;
    final ViewPadding pxPadding = view.viewPadding;
    final double ratio = view.devicePixelRatio;
    double realTop = pxPadding.top / ratio;

    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: EdgeInsets.fromLTRB(12, realTop + 8, 12, 8),
              decoration: BoxDecoration(
                color: t.appBarColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 搜索框
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.inputBgColor,
                      borderRadius: BorderRadius.circular(t.inputRadius),
                    ),
                    child: TextFormField(
                      controller: _searchCtrl,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      style: t.bodyStyle,
                      onChanged: (value) {
                        // 防抖实时搜索
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                          _bookController.searchBooks(value.trim());
                          _currentTab.value = 0;
                        });
                      },
                      onFieldSubmitted: (value) {
                        _searchDebounce?.cancel();
                        _bookController.searchBooks(value.trim());
                        _currentTab.value = 0;
                        FocusScope.of(context).unfocus();
                      },
                      decoration: InputDecoration(
                        hintText: "搜索书籍",
                        hintStyle: t.captionStyle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(t.inputRadius),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(t.inputRadius),
                          borderSide: BorderSide(color: t.primaryColor, width: 1.5),
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: t.hintTextColor, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _bookController.searchBooks('');
                                },
                              )
                            : Icon(Icons.search, color: t.hintTextColor, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tab 切换
                  Row(
                    children: [
                      _buildTabItem(0, '推荐', t),
                      const SizedBox(width: 8),
                      _buildTabItem(1, '我的书架', t),
                    ],
                  ),
                  // 分类标签（仅推荐页显示）
                  if (_currentTab.value == 0 && _bookController.categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _bookController.categories.length + 1,
                        itemBuilder: (context, index) {
                          final isAll = index == 0;
                          final cat = isAll ? '' : _bookController.categories[index - 1];
                          final isSelected = _bookController.selectedCategory.value == cat;
                          return GestureDetector(
                            onTap: () => _bookController.selectCategory(cat),
                            child: Container(
                              margin: EdgeInsets.only(right: 8, left: index == 0 ? 0 : 0),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? t.primaryColor : t.inputBgColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected ? t.primaryColor : t.dividerColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isAll ? '全部' : cat,
                                style: t.captionStyle.copyWith(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : t.fontColor,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // 书架筛选（仅书架页显示）
                  if (_currentTab.value == 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildFilterChip(0, '全部', t),
                        const SizedBox(width: 8),
                        _buildFilterChip(1, '想读', t),
                        const SizedBox(width: 8),
                        _buildFilterChip(2, '在读', t),
                        const SizedBox(width: 8),
                        _buildFilterChip(3, '已读', t),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 内容区
            Expanded(
              child: Container(
                color: t.scaffoldBg,
                child: Column(
                  children: [
                    // 搜索状态提示
                    if (_bookController.searchKeyword.value.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.primaryColor.withOpacity(0.08),
                          border: Border(
                            bottom: BorderSide(color: t.dividerColor, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 14, color: t.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '搜索：「${_bookController.searchKeyword.value}」',
                                style: t.captionStyle.copyWith(
                                  color: t.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _bookController.searchBooks('');
                              },
                              child: Icon(Icons.close, size: 16, color: t.hintTextColor),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _currentTab.value == 0 ? _buildBooksGrid(t) : _buildShelfGrid(t),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabItem(int index, String label, AppTheme t) {
    final isSelected = _currentTab.value == index;
    return GestureDetector(
      onTap: () => _currentTab.value = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? t.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: t.bodyStyle.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : t.hintTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(int status, String label, AppTheme t) {
    final isSelected = _bookController.shelfFilter.value == status;
    return GestureDetector(
      onTap: () => _bookController.setShelfFilter(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? t.primaryColor.withOpacity(0.15) : t.inputBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? t.primaryColor : t.dividerColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: t.captionStyle.copyWith(
            fontSize: 11,
            color: isSelected ? t.primaryColor : t.fontColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBooksGrid(AppTheme t) {
    final isSearching = _bookController.searchKeyword.value.isNotEmpty;
    if (_bookController.books.isEmpty && !_bookController.booksLoading.value) {
      return _emptyState(
        t,
        isSearching ? '🔍' : '📚',
        isSearching
            ? '未找到「${_bookController.searchKeyword.value}」相关书籍'
            : '暂无图书，试试搜索或添加',
      );
    }

    return RefreshIndicator(
      onRefresh: _bookController.refreshBooks,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        itemCount: _bookController.books.length +
            (_bookController.booksLoading.value ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        itemBuilder: (context, index) {
          if (index >= _bookController.books.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final book = _bookController.books[index];
          return BookCard(
            book: book,
            onTap: () => Get.to(() => BookDetailPage(bookUid: book.bookUid)),
          );
        },
      ),
    );
  }

  Widget _buildShelfGrid(AppTheme t) {
    if (_bookController.shelf.isEmpty && !_bookController.shelfLoading.value) {
      return _emptyState(t, '📖', '书架空空如也，去推荐页添加吧');
    }

    return RefreshIndicator(
      onRefresh: _bookController.refreshShelf,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        itemCount: _bookController.shelf.length +
            (_bookController.shelfLoading.value ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        itemBuilder: (context, index) {
          if (index >= _bookController.shelf.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final shelfBook = _bookController.shelf[index];
          return BookCard(
            book: shelfBook.book,
            shelfBook: shelfBook,
            showProgress: true,
            onTap: () => Get.to(() => BookDetailPage(bookUid: shelfBook.book.bookUid)),
          );
        },
      ),
    );
  }

  Widget _emptyState(AppTheme t, String icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(text, style: t.captionStyle),
        ],
      ),
    );
  }
}
