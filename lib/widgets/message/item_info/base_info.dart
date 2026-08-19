abstract class BaseInfoItem {
  String uid; // 当前消息的数据归属 uid
  String nickname;
  String avatarUrl;

  BaseInfoItem({
    required this.uid,
    required this.nickname,
    required this.avatarUrl,
  });
}
