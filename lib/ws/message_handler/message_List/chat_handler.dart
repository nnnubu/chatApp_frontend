import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/message_handler/base_handler.dart';

class ChatHandler extends BaseMessageHanlder {
  @override
  Future<MessageBusEvent?> handle(MessageDto dto) async {
    final Map<String, dynamic>? data = dto.data;
    final String? msgId = dto.msgId;
    if (data == null || msgId == null || msgId.isEmpty) return null;

    ChatItem chatMessageItem = ChatItem(
      msgId: msgId,
      uid: data["uid"],
      senderUid: data["senderUid"],
      receiverUid: data["receiverUid"],
      nickname: data["nickname"],
      avatarUrl: data["avatarUrl"],
      conversationUid: data["conversationUid"],
      content: data["content"],
      isInsertToTop: data["isInsertToTop"]
    );
    return MessageListEvent(item: chatMessageItem);
  }

  @override
  MessageType supportType() {
    return MessageType.chat;
  }
}
