import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'cached_chat_message.dart';

/// 聊天消息本地缓存服务（阶段三：Isar 消息表）
/// 全局单例，按会话存储消息，每行一条；msgSeq 为雪花 id 数值保证跨批次有序。
/// 在线拉取成功/新消息到达/撤回时写入，离线时读取兜底渲染。
class MessageCacheService {
  MessageCacheService._();
  static final MessageCacheService instance = MessageCacheService._();

  Isar? _isar;
  bool _initialized = false;

  /// 初始化 Isar，在 App 启动时调用一次
  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [CachedChatMessageSchema],
      directory: dir.path,
      name: 'message_cache',
    );
    _initialized = true;
  }

  Isar get _db {
    if (_isar == null || !_initialized) {
      throw StateError('MessageCacheService 未初始化，请先调用 init()');
    }
    return _isar!;
  }

  /// 批量保存消息（在线拉取历史成功后调用）
  /// 同 msgId 的消息按覆盖更新处理（如撤回状态变更）
  Future<void> saveMessages(String conversationUid, List<dynamic> messages) async {
    final now = DateTime.now();
    await _db.writeTxn(() async {
      for (final raw in messages) {
        if (raw is! Map<String, dynamic>) continue;
        final msgId = raw['msgId'];
        if (msgId is! String || msgId.isEmpty) continue;
        final msgSeq = int.tryParse(msgId) ?? 0;
        final existing = await _db.cachedChatMessages
            .filter()
            .messageIdEqualTo(msgId)
            .findFirst();
        if (existing != null) {
          existing.payload = jsonEncode(raw);
          existing.cachedAt = now;
          await _db.cachedChatMessages.put(existing);
        } else {
          await _db.cachedChatMessages.put(CachedChatMessage(
            messageId: msgId,
            conversationUid: conversationUid,
            msgSeq: msgSeq,
            payload: jsonEncode(raw),
            cachedAt: now,
          ));
        }
      }
    });
  }

  /// 单条保存（WebSocket 新消息到达 / 撤回状态更新）
  Future<void> saveMessage(String conversationUid, Map<String, dynamic> msg) async {
    await saveMessages(conversationUid, [msg]);
  }

  /// 读取会话消息，按时间倒序（新→旧，与后端 pullHistoryMessage 返回顺序一致）
  /// 前端 dispatch 时逐条插入队首，最终数据源为正序（旧→新），与在线拉取一致
  /// [limit] 只取最新 N 条（用于离线恢复时避免一次性渲染过多）
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationUid, {
    int? limit,
  }) async {
    final all = await _db.cachedChatMessages
        .filter()
        .conversationUidEqualTo(conversationUid)
        .sortByMsgSeqDesc()
        .findAll();
    var list = all;
    if (limit != null && list.length > limit) {
      list = list.sublist(0, limit);
    }
    final result = <Map<String, dynamic>>[];
    for (final e in list) {
      try {
        result.add(jsonDecode(e.payload) as Map<String, dynamic>);
      } catch (_) {
        // 单条损坏忽略，不影响其他消息
      }
    }
    return result;
  }

  /// 会话是否存在缓存消息
  Future<bool> hasMessages(String conversationUid) async {
    final count = await _db.cachedChatMessages
        .filter()
        .conversationUidEqualTo(conversationUid)
        .count();
    return count > 0;
  }

  /// 标记撤回：更新指定消息 payload 中 data.recalled = true
  Future<void> markRecalled(String messageId) async {
    await _db.writeTxn(() async {
      final entry = await _db.cachedChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (entry == null) return;
      try {
        final json = jsonDecode(entry.payload) as Map<String, dynamic>;
        final data = json['data'];
        if (data is Map<String, dynamic>) {
          data['recalled'] = true;
          entry.payload = jsonEncode(json);
          entry.cachedAt = DateTime.now();
          await _db.cachedChatMessages.put(entry);
        }
      } catch (_) {
        // payload 解析失败则忽略
      }
    });
  }

  /// 删除指定会话的全部缓存（退出登录清理时按需调用）
  Future<void> deleteConversation(String conversationUid) async {
    await _db.writeTxn(() async {
      await _db.cachedChatMessages
          .filter()
          .conversationUidEqualTo(conversationUid)
          .deleteAll();
    });
  }

  /// 清空全部消息缓存
  Future<void> clearAll() async {
    await _db.writeTxn(() => _db.cachedChatMessages.clear());
  }
}
