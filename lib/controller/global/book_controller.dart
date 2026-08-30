import 'package:chatapp/dto/dto_book.dart';
import 'package:chatapp/service/book_service.dart';
import 'package:get/get.dart';

/// 图书模块控制器
class BookController extends GetxController {
  static BookController get to => Get.find();

  // 推荐/全部图书列表
  final RxList<BookInfo> books = <BookInfo>[].obs;
  final RxBool booksLoading = false.obs;
  final RxBool booksHasMore = true.obs;
  final RxInt booksPage = 1.obs;

  // 书架
  final RxList<ShelfBook> shelf = <ShelfBook>[].obs;
  final RxBool shelfLoading = false.obs;
  final RxBool shelfHasMore = true.obs;
  final RxInt shelfPage = 1.obs;
  final RxInt shelfFilter = 0.obs; // 0:全部 1:想读 2:在读 3:已读

  // 分类
  final RxList<String> categories = <String>[].obs;
  final RxString selectedCategory = ''.obs;

  // 搜索
  final RxString searchKeyword = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
    refreshBooks();
    refreshShelf();
  }

  /// 加载分类
  Future<void> loadCategories() async {
    final result = await BookService.bookCategories();
    if (result.isSuccess) {
      categories.value = result.data as List<String>;
    }
  }

  /// 刷新图书列表
  Future<void> refreshBooks() async {
    booksPage.value = 1;
    booksHasMore.value = true;
    books.clear();
    await loadMoreBooks();
  }

  /// 加载更多图书
  Future<void> loadMoreBooks() async {
    if (booksLoading.value || !booksHasMore.value) return;
    booksLoading.value = true;

    final result = await BookService.pullBooks(
      category: selectedCategory.value,
      keyword: searchKeyword.value,
      page: booksPage.value,
      pageSize: 20,
    );

    if (result.isSuccess) {
      final data = result.data as Map<String, dynamic>;
      books.addAll(data['books'] as List<BookInfo>);
      booksHasMore.value = data['hasMore'] as bool;
      booksPage.value++;
    }
    booksLoading.value = false;
  }

  /// 搜索图书
  Future<void> searchBooks(String keyword) async {
    searchKeyword.value = keyword;
    await refreshBooks();
  }

  /// 切换分类
  Future<void> selectCategory(String category) async {
    selectedCategory.value = category;
    await refreshBooks();
  }

  /// 刷新书架
  Future<void> refreshShelf() async {
    shelfPage.value = 1;
    shelfHasMore.value = true;
    shelf.clear();
    await loadMoreShelf();
  }

  /// 加载更多书架
  Future<void> loadMoreShelf() async {
    if (shelfLoading.value || !shelfHasMore.value) return;
    shelfLoading.value = true;

    final result = await BookService.pullShelf(
      status: shelfFilter.value,
      page: shelfPage.value,
      pageSize: 20,
    );

    if (result.isSuccess) {
      final data = result.data as Map<String, dynamic>;
      shelf.addAll(data['books'] as List<ShelfBook>);
      shelfHasMore.value = data['hasMore'] as bool;
      shelfPage.value++;
    }
    shelfLoading.value = false;
  }

  /// 切换书架筛选
  Future<void> setShelfFilter(int status) async {
    shelfFilter.value = status;
    await refreshShelf();
  }

  /// 添加到书架
  Future<bool> addToShelf(String bookUid, {int status = 1}) async {
    final result = await BookService.addToShelf(bookUid, status: status);
    if (result.isSuccess) {
      refreshShelf();
    }
    return result.isSuccess;
  }

  /// 更新阅读进度
  Future<void> updateProgress(String bookUid, int page) async {
    await BookService.updateProgress(bookUid, page);
    final idx = shelf.indexWhere((e) => e.book.bookUid == bookUid);
    if (idx >= 0) {
      shelf[idx] = ShelfBook(
        book: shelf[idx].book,
        status: shelf[idx].status,
        currentPage: page,
        rating: shelf[idx].rating,
        note: shelf[idx].note,
        addedAt: shelf[idx].addedAt,
      );
    }
  }

  /// 从书架移除
  Future<bool> removeFromShelf(String bookUid) async {
    final result = await BookService.removeFromShelf(bookUid);
    if (result.isSuccess) {
      shelf.removeWhere((e) => e.book.bookUid == bookUid);
    }
    return result.isSuccess;
  }

  /// 检查图书是否在书架
  bool isInShelf(String bookUid) {
    return shelf.any((e) => e.book.bookUid == bookUid);
  }
}
