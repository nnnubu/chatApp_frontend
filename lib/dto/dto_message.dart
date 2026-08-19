import 'package:chatapp/constants/app_constants.dart';

class MessageDto {
  MessageType msgType;
  // 当前消息的 msgId 可为 null 是为了兼容 ack 和 pong 包
  // 仅业务消息诸如 好友请求 聊天消息等有 msgId

  // 后端发送给前端携带 msgId 用于 ack 包确认前端收到 并且作为消息的持久化存储唯一 id
  String? msgId;
  // 前端发送给后端携带 requestId 用于 ack 包确认后端收到与否
  String? requestId;
  Map<String, dynamic>? data;

  MessageDto({
    required this.msgType,
    this.msgId,
    this.requestId,
    required this.data,
  });

  // 后端发送给前端
  factory MessageDto.formJson(Map<String, dynamic> json) {
    MessageType rawType;
    switch (json["msgType"]) {
      case "ready":
        rawType = MessageType.ready;
        break;
      case "pong":
        rawType = MessageType.heartBeat;
        break;
      case "ack":
        rawType = MessageType.ack;
        break;
      case "addFriend":
        rawType = MessageType.addFriend;
        break;
      case "chat":
        rawType = MessageType.chat;
        break;
      case "markRead":
        rawType = MessageType.markRead;
        break;
      case "pullCategory":
        rawType = MessageType.pullCategory;
        break;
      default:
        rawType = MessageType.nil;
        break;
    }
    return MessageDto(
      msgType: rawType,
      msgId: json["msgId"],
      requestId: json["requestId"],
      data: json["data"],
    );
  }

  // 前端发送给后端
  Map<String, dynamic> toJson() {
    String? rawTypeStr;
    switch (msgType) {
      case MessageType.heartBeat:
        rawTypeStr = "ping";
        break;
      case MessageType.ack:
        rawTypeStr = "ack";
        break;
      case MessageType.addFriend:
        rawTypeStr = "addFriend";
        break;
      case MessageType.chat:
        rawTypeStr = "chat";
        break;
      case MessageType.markRead:
        rawTypeStr = "markRead";
        break;
      default:
        rawTypeStr = null;
    }
    final json = <String, dynamic>{"msgType": rawTypeStr, "data": data};

    // 前端发送给后端确认收到时携带 requestId 发送消息前的序列化添加 requestId 后端 ack 返回 requestId 确认消息接收成功
    if (requestId != null && requestId!.isNotEmpty) {
      json["requestId"] = requestId;
    }

    // 发给后端默认无 msgId 由后端生成返回 msgId 前端再返回回后端序列化时传递 msgId 确认消息接收成功
    if (msgId != null && msgId!.isNotEmpty) {
      json["msgId"] = msgId;
    }
    return json;
  }
}
