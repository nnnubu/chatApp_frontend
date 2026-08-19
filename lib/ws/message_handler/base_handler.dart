import 'package:chatapp/constants/app_constants.dart';

import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';

abstract class BaseMessageHanlder {
  // 返回支持的消息类型
  MessageType supportType();
  // 执行消息处理逻辑
  Future<MessageBusEvent?> handle(MessageDto dto);
}