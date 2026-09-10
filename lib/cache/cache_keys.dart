/// 业务缓存键常量
/// 命名规则：{业务域}_{标识}
class CacheKeys {
  CacheKeys._();

  // ===== 消息中心 =====
  /// 会话列表（消息中心的会话预览）
  static const String conversationList = 'msg_conversation_list';

  /// 未读消息（离线消息拉取结果）
  static const String unreadMessages = 'msg_unread_messages';

  // ===== 好友 =====
  /// 好友分类列表
  static const String friendCategories = 'friend_categories';

  /// 某个分类下的好友列表，key 后拼分类名，如 friend_items_好友
  static String friendItems(String categoryName) => 'friend_items_$categoryName';

  /// 离线好友请求
  static const String offlineFriendApply = 'friend_offline_apply';

  // ===== 表情包 =====
  /// 用户收藏的表情包列表
  static const String userStickers = 'sticker_user_list';

  // ===== 用户资料 =====
  /// 其他用户资料缓存，key 后拼 uid，如 user_profile_01a01e2e...
  static String userProfile(String uid) => 'user_profile_$uid';
}
