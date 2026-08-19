import 'dart:async';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_handler/base_handler.dart';
import 'package:flutter/rendering.dart';

// 初始抽象类消息总线事件 外部订阅根据不同的实现类来获取数据
abstract class MessageBusEvent {}

// 消息列表事件
class MessageListEvent extends MessageBusEvent {
  // 原始组装完成的消息实体
  final BaseInfoItem item;
  MessageListEvent({required this.item});
}

// 分类列表事件
class CategoryListEvent extends MessageBusEvent {
  final CategoryInfo? info;
  final CategoryItem? item;
  CategoryListEvent({this.info,this.item});
}

class MessageDispatcher {
  static final MessageDispatcher instance = MessageDispatcher._internal();
  MessageDispatcher._internal();

  // 不同消息类型对应不同的封装 handler
  final Map<MessageType, BaseMessageHanlder> _handlerMap = {};

  // 消息总线
  final StreamController<MessageBusEvent> _eventBus =
      StreamController.broadcast();
  Stream<MessageBusEvent> get eventBus => _eventBus.stream;

  void registerHandler(List<BaseMessageHanlder> handlers) {
    for (final h in handlers) {
      _handlerMap[h.supportType()] = h;
    }
  }

  // 原始消息封装好后传入 service 层 再传入此处
  // 此处 再封装为可用 item 推送事件给 各个页面的 item 控制器
  // 解析完毕则广播事件
  Future<void> dispatch(MessageDto dto) async {
    final handler = _handlerMap[dto.msgType];
    if (handler == null) {
      debugPrint("未注册处理器,消息类型：${dto.msgType}");
      return;
    }
    try {
      final event = await handler.handle(dto);
      if (event != null) {
        // 推送事件给订阅了此分发服务的页面
        _eventBus.add(event);
      }
    } catch (e) {
      debugPrint("消息处理异常：$e");
      return;
    }
  }

  void dispose() {
    _eventBus.close();
  }
}
