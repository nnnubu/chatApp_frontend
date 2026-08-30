import 'package:dio/dio.dart';
import 'package:chatapp/dto/dto_base.dart';

class BookApi {
  /// 拉取图书列表（支持分类筛选和搜索）
  static Future<Map<String, dynamic>?> pullBooks({
    String category = '',
    String keyword = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (category.isNotEmpty) params['category'] = category;
    if (keyword.isNotEmpty) params['keyword'] = keyword;

    Response res = await DioUtil.dio.get(
      'auth/pullBooks',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>?;
  }

  /// 获取图书详情
  static Future<Map<String, dynamic>?> bookDetail(String bookUid) async {
    Response res = await DioUtil.dio.get(
      'auth/bookDetail',
      queryParameters: {'bookUid': bookUid},
    );
    return res.data as Map<String, dynamic>?;
  }

  /// 获取图书分类列表
  static Future<Map<String, dynamic>?> bookCategories() async {
    Response res = await DioUtil.dio.get('auth/bookCategories');
    return res.data as Map<String, dynamic>?;
  }

  /// 添加到书架
  static Future<Map<String, dynamic>?> addToShelf(String bookUid, {int status = 1}) async {
    Response res = await DioUtil.dio.post(
      'auth/addToShelf',
      data: {'bookUid': bookUid, 'status': status},
    );
    return res.data as Map<String, dynamic>?;
  }

  /// 拉取书架
  static Future<Map<String, dynamic>?> pullShelf({
    int status = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (status > 0) params['status'] = status;

    Response res = await DioUtil.dio.get(
      'auth/pullShelf',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>?;
  }

  /// 更新书架信息（阅读进度/评分/笔记/状态）
  static Future<Map<String, dynamic>?> updateShelf({
    required String bookUid,
    int? status,
    int? currentPage,
    int? rating,
    String? note,
  }) async {
    final data = <String, dynamic>{'bookUid': bookUid};
    if (status != null) data['status'] = status;
    if (currentPage != null) data['currentPage'] = currentPage;
    if (rating != null) data['rating'] = rating;
    if (note != null) data['note'] = note;

    Response res = await DioUtil.dio.post('auth/updateShelf', data: data);
    return res.data as Map<String, dynamic>?;
  }

  /// 从书架移除
  static Future<Map<String, dynamic>?> removeFromShelf(String bookUid) async {
    Response res = await DioUtil.dio.delete(
      'auth/removeFromShelf',
      queryParameters: {'bookUid': bookUid},
    );
    return res.data as Map<String, dynamic>?;
  }
}
