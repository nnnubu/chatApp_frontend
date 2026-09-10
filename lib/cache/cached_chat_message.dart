import 'package:isar/isar.dart';

part 'cached_chat_message.g.dart';

/// 聊天消息本地缓存（阶段三：Isar 消息表）
/// 按会话存储，每行一条消息；msgSeq 为雪花 id 的数值（大=新），
/// 保证跨页、跨批次的全局有序，天然适配后端 msg_id desc / 前端正序渲染。
@collection
class CachedChatMessage {
  Id id = Isar.autoIncrement;

  /// 后端消息 msgId，全局唯一
  @Index(unique: true)
  late String messageId;

  /// 所属会话 uid
  @Index()
  late String conversationUid;

  /// 雪花 id 数值（大=新），用于排序
  late int msgSeq;

  /// 消息完整原始 JSON（{msgType, msgId, requestId, data}）
  late String payload;

  /// 缓存写入时间（用于过期清理）
  late DateTime cachedAt;

  CachedChatMessage({
    required this.messageId,
    required this.conversationUid,
    required this.msgSeq,
    required this.payload,
    required this.cachedAt,
  });
}
