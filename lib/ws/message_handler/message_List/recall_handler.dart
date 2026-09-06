import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/message_handler/base_handler.dart';

/// 撤回消息事件：携带被撤回消息的 msgId / 会话 / 发送方
class RecallEvent extends MessageBusEvent {
  final String msgId;
  final String conversationUid;
  final String senderUid;
  final String receiverUid;
  RecallEvent({
    required this.msgId,
    required this.conversationUid,
    required this.senderUid,
    required this.receiverUid,
  });
}

class RecallHandler extends BaseMessageHanlder {
  @override
  Future<MessageBusEvent?> handle(MessageDto dto) async {
    final Map<String, dynamic>? data = dto.data;
    if (data == null) return null;
    final String? msgId = data["msgId"];
    if (msgId == null || msgId.isEmpty) return null;
    return RecallEvent(
      msgId: msgId,
      conversationUid: data["conversationUid"] ?? "",
      senderUid: data["senderUid"] ?? "",
      receiverUid: data["receiverUid"] ?? "",
    );
  }

  @override
  MessageType supportType() {
    return MessageType.recall;
  }
}
