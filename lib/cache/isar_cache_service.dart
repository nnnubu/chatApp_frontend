import 'dart:async';
import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_entry.dart';

/// Isar 业务缓存服务
/// 全局单例，提供 key-value 缓存读写，支持 TTL 过期自动清理
class IsarCacheService {
  IsarCacheService._();
  static final IsarCacheService instance = IsarCacheService._();

  Isar? _isar;
  bool _initialized = false;

  /// 初始化 Isar，在 App 启动时调用一次
  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [CacheEntrySchema],
      directory: dir.path,
      name: 'business_cache',
    );
    _initialized = true;
    // 启动时清理一次过期缓存
    unawaited(clearExpired());
  }

  Isar get _db {
    if (_isar == null || !_initialized) {
      throw StateError('IsarCacheService 未初始化，请先调用 init()');
    }
    return _isar!;
  }

  /// 读取缓存，返回解码后的 JSON 对象；未命中或已过期返回 null
  Future<Map<String, dynamic>?> getJson(String key) async {
    final entry = await _db.cacheEntrys.filter().keyEqualTo(key).findFirst();
    if (entry == null) return null;
    if (entry.isExpired) {
      // 过期则删除
      await _db.writeTxn(() => _db.cacheEntrys.delete(entry.id));
      return null;
    }
    try {
      return jsonDecode(entry.value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 读取缓存，返回解码后的 List；未命中或已过期返回 null
  Future<List<dynamic>?> getList(String key) async {
    final entry = await _db.cacheEntrys.filter().keyEqualTo(key).findFirst();
    if (entry == null) return null;
    if (entry.isExpired) {
      await _db.writeTxn(() => _db.cacheEntrys.delete(entry.id));
      return null;
    }
    try {
      return jsonDecode(entry.value) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 写入缓存，value 为可 JSON 序列化的对象
  /// [ttlSeconds] 过期时间（秒），0 表示永不过期
  Future<void> setJson(String key, dynamic value, {int ttlSeconds = 0}) async {
    final jsonStr = jsonEncode(value);
    await _db.writeTxn(() async {
      final existing = await _db.cacheEntrys.filter().keyEqualTo(key).findFirst();
      if (existing != null) {
        existing.value = jsonStr;
        existing.lastUpdatedAt = DateTime.now();
        existing.ttlSeconds = ttlSeconds;
        await _db.cacheEntrys.put(existing);
      } else {
        await _db.cacheEntrys.put(CacheEntry(
          key: key,
          value: jsonStr,
          lastUpdatedAt: DateTime.now(),
          ttlSeconds: ttlSeconds,
        ));
      }
    });
  }

  /// 删除指定缓存
  Future<void> delete(String key) async {
    await _db.writeTxn(() async {
      final entry = await _db.cacheEntrys.filter().keyEqualTo(key).findFirst();
      if (entry != null) {
        await _db.cacheEntrys.delete(entry.id);
      }
    });
  }

  /// 清理所有过期缓存
  Future<int> clearExpired() async {
    final now = DateTime.now();
    final expired = await _db.cacheEntrys
        .filter()
        .ttlSecondsGreaterThan(0)
        .and()
        .lastUpdatedAtLessThan(now.subtract(const Duration(days: 365)))
        .findAll();
    // 上面的过滤不够精确（Isar 不支持复杂表达式），改用内存过滤
    final all = await _db.cacheEntrys.where().findAll();
    final toDelete = all.where((e) => e.isExpired).map((e) => e.id).toList();
    if (toDelete.isNotEmpty) {
      await _db.writeTxn(() => _db.cacheEntrys.deleteAll(toDelete));
    }
    return toDelete.length;
  }

  /// 清空全部缓存（退出登录时调用）
  Future<void> clearAll() async {
    await _db.writeTxn(() => _db.cacheEntrys.clear());
  }
}
