import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class MessageListOperate extends ListEvent {
  final int index; // 数据源索引
  final ListOperateType type; // 删除 添加
  final BaseInfoItem item; // 列表元素
  MessageListOperate({
    required this.type,
    required this.index,
    required this.item,
  });
}

class MessageList {
  // RxList 当列表增删元素，或内部元素变更 则会触发 Obx 更新
  final RxList<BaseInfoItem> _messageList = <BaseInfoItem>[].obs;

  RxList<BaseInfoItem> get dataSource => _messageList;

  // 此处的 newItem 可能有几类 如 ChatMessageItem 或 FriendApplyMessageItem 并不是都根据 uid 来区分是否为新元素 聊天类消息当以 会话id 作为旧消息标识

  bool addItem(BaseInfoItem newItem) {
    if (newItem is FriendApplyMessageItem) {
      final existIndex = _messageList.indexWhere(
        (item) => item.uid == newItem.uid,
      );
      if (existIndex != -1) {
        // 若已存在：仅更新最新内容，不新增条目
        _messageList[existIndex] = newItem;
        return false;
      }
    } else if (newItem is ChatItem) {
      // 拉取历史消息不更新内容
      if (newItem.isInsertToTop == true) {
        return false;
      }
      final existIndex = _messageList.indexWhere(
        (item) =>
            item is ChatItem && item.conversationUid == newItem.conversationUid,
      );
      // 只更新最新消息
      if (existIndex != -1) {
        // 未读数量增加
        newItem.unReadCount.value +=
            (_messageList[existIndex] as ChatItem).unReadCount.value;
        _messageList[existIndex] = newItem;
        return false;
      }
    }
    _messageList.insert(0, newItem);
    return true;
  }

  ({int? existIndex, BaseInfoItem? removeItem}) deleteItem(String targetUid) {
    int existIndex = _messageList.indexWhere((e) => e.uid == targetUid);
    if (existIndex == -1) {
      return (existIndex: null, removeItem: null);
    }
    // 保存旧数据 并从列表中删除元素 否则会出现动画执行完毕，下一条消息变成上一条消息的情况
    BaseInfoItem removeItem = _messageList.removeAt(existIndex);
    return (existIndex: existIndex, removeItem: removeItem);
  }

  Future<void> clearUnReadCount(String conversationUid) async {
    final existIndex = _messageList.indexWhere(
      (item) => item is ChatItem && item.conversationUid == conversationUid,
    );
    if (existIndex != -1) {
      (_messageList[existIndex] as ChatItem).unReadCount.value = 0;
    }
  }

  void clear() {
    _messageList.clear();
  }
}
