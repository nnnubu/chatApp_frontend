import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

// 此组件共用于 MessageList 以及 ChatList
class ChatItem extends BaseInfoItem {
  String? content;
  final RxInt unReadCount;
  final String? msgId; // 后端推送给前端必带以下 4 条字段
  final String? senderUid; // 消息发送方
  final String? receiverUid; // 消息接收方
  final String? conversationUid; // 隶属会话标识
  bool isInsertToTop; // 是否插入队首

  ChatItem({
    required super.uid,
    required super.nickname,
    required super.avatarUrl,
    this.msgId,
    this.senderUid,
    this.receiverUid,
    this.conversationUid,
    this.content,
    this.isInsertToTop = false,
    int unReadCount = 1,
  }) : unReadCount = unReadCount.obs;
}
