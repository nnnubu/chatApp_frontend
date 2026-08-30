import 'package:dio/dio.dart';
import 'package:chatapp/api/book_api.dart';
import 'package:chatapp/dto/dto_book.dart';
import 'package:chatapp/service/user_service.dart';

class BookService {
  /// 拉取图书列表
  static Future<CommonState> pullBooks({
    String category = '',
    String keyword = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await BookApi.pullBooks(
        category: category,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
      if (data == null) {
        return CommonState(isSuccess: false, msg: '获取图书列表失败');
      }
      final List<dynamic> booksJson = data['books'] ?? [];
      final books = booksJson.map((e) => BookInfo.fromJson(e)).toList();
      return CommonState(
        isSuccess: true,
        msg: '',
        data: {
          'books': books,
          'total': data['total'] ?? 0,
          'hasMore': data['hasMore'] ?? false,
          'page': data['page'] ?? page,
        },
      );
    } catch (e) {
      return CommonState(
        isSuccess: false,
        msg: e is DioException ? (e.message ?? '网络错误') : '网络错误',
      );
    }
  }

  /// 获取图书详情
  static Future<CommonState> bookDetail(String bookUid) async {
    try {
      final data = await BookApi.bookDetail(bookUid);
      if (data == null) {
        return CommonState(isSuccess: false, msg: '获取图书详情失败');
      }
      return CommonState(
        isSuccess: true,
        msg: '',
        data: BookInfo.fromJson(data),
      );
    } catch (e) {
      return CommonState(
        isSuccess: false,
        msg: e is DioException ? (e.message ?? '网络错误') : '网络错误',
      );
    }
  }

  /// 获取分类列表
  static Future<CommonState> bookCategories() async {
    try {
      final data = await BookApi.bookCategories();
      if (data == null) {
        return CommonState(isSuccess: false, msg: '获取分类失败');
      }
      final List<dynamic> cats = data['categories'] ?? [];
      return CommonState(isSuccess: true, msg: '', data: cats.cast<String>());
    } catch (e) {
      return CommonState(
        isSuccess: false,
        msg: e is DioException ? (e.message ?? '网络错误') : '网络错误',
      );
    }
  }

  /// 添加到书架
  static Future<CommonState> addToShelf(String bookUid, {int status = 1}) async {
    try {
      await BookApi.addToShelf(bookUid, status: status);
      return CommonState(isSuccess: true, msg: '已添加到书架');
    } catch (e) {
      return CommonState(
        isSuccess: false,
        msg: e is DioException ? (e.message ?? '操作失败') : '操作失败',
      );
    }
  }

  /// 拉取书架
  static Future<CommonState> pullShelf({
    int status = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await BookApi.pullShelf(
        status: status,
        page: page,
        pageSize: pageSize,
      );
      if (data == null) {
        return CommonState(isSuccess: false, msg: '获取书架失败');
      }
      final List<dynamic> booksJson = data['books'] ?? [];
      final books = booksJson.map((e) => ShelfBook.fromJson(e)).toList();
      return CommonState(
        isSuccess: true,
        msg: '',
        data: {
          'books': books,
          'total': data['total'] ?? 0,
          'hasMore': data['hasMore'] ?? false,
        },
      );
    } catch (e) {
      return CommonState(
        isSuccess: false,
        msg: e is DioException ? (e.message ?? '网络错误') : '网络错误',
      );
    }
  }

  /// 更新阅读进度
  static Future<CommonState> updateProgress(String bookUid, int currentPage) async {
    try {
      await BookApi.updateShelf(bookUid: bookUid, currentPage: currentPage);
      return CommonState(isSuccess: true, msg: '进度已更新');
    } catch (e) {
      return CommonState(isSuccess: false, msg: '更新失败');
    }
  }

  /// 更新评分
  static Future<CommonState> updateRating(String bookUid, int rating) async {
    try {
      await BookApi.updateShelf(bookUid: bookUid, rating: rating);
      return CommonState(isSuccess: true, msg: '评分已更新');
    } catch (e) {
      return CommonState(isSuccess: false, msg: '更新失败');
    }
  }

  /// 从书架移除
  static Future<CommonState> removeFromShelf(String bookUid) async {
    try {
      await BookApi.removeFromShelf(bookUid);
      return CommonState(isSuccess: true, msg: '已移除');
    } catch (e) {
      return CommonState(isSuccess: false, msg: '移除失败');
    }
  }
}
