import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/message_handler/base_handler.dart';
import 'package:get/get.dart';

class FriendApplyHandler extends BaseMessageHanlder {
  @override
  Future<MessageBusEvent?> handle(MessageDto dto) async {
    final Map<String, dynamic>? data = dto.data;
    final String? msgId = dto.msgId;
    if (data == null || msgId == null || msgId.isEmpty) return null;

    final MessageType msgType = dto.msgType;
    MessageType typeVal;
    int? status = data["status"];
    if (status == 1) {
      typeVal = MessageType.argee;
    } else if (status == 2) {
      typeVal = MessageType.refuse;
    } else {
      typeVal = msgType;
    }
    FriendApplyMessageItem friendApplyMessageItem = FriendApplyMessageItem(
      uid: data["uid"],
      nickname: data["nickname"],
      avatarUrl: data["avatarUrl"],
      lastContent: data["content"],
      status: status ?? 0,
      msgId: msgId,
      applyUid: data["applyUid"],
      targetUid: data["targetUid"],
      typeVal: typeVal,
      unReadCount: 1.obs,
    );
    return MessageListEvent(item: friendApplyMessageItem);
  }

  @override
  MessageType supportType() {
    return MessageType.addFriend;
  }
}
