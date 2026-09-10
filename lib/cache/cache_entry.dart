import 'package:isar/isar.dart';

part 'cache_entry.g.dart';

/// 通用业务缓存表
/// 采用 key-value 结构，value 存 JSON 字符串，配合 TTL 过期策略
/// 适用于会话列表、好友分类、好友列表、表情包等"整体读、整体写"的业务缓存
@collection
class CacheEntry {
  Id id = Isar.autoIncrement;

  /// 缓存键，唯一索引
  @Index(unique: true)
  late String key;

  /// 缓存值，JSON 字符串
  late String value;

  /// 最后更新时间
  late DateTime lastUpdatedAt;

  /// TTL（秒），0 表示永不过期
  late int ttlSeconds;

  /// 是否已过期
  bool get isExpired {
    if (ttlSeconds <= 0) return false;
    return DateTime.now().difference(lastUpdatedAt).inSeconds > ttlSeconds;
  }

  CacheEntry({
    required this.key,
    required this.value,
    required this.lastUpdatedAt,
    this.ttlSeconds = 0,
  });
}
