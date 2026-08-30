import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:get/get.dart';

class ChatListOperate extends ListEvent {
  final int index;
  final ListOperateType type;
  final ChatItem item;
  ChatListOperate({
    required this.type,
    required this.index,
    required this.item,
  });
}

class ConversationState {
  final RxList<ChatItem> messageList;
  final String conversationUid;
  bool hasMore;
  ConversationState({required this.conversationUid, this.hasMore = true}) : messageList = <ChatItem>[].obs;
}

class ChatList {
  // 以 conversationUid 为 key , 其中的 value 为该会话下的专用列表
  final RxMap<String, ConversationState> _chatMap = RxMap({});
  final UserController userController = Get.find<UserController>();
  ConversationState getConversationState(String conversationUid) {
    if (!_chatMap.containsKey(conversationUid)) {
      _chatMap[conversationUid] = ConversationState(
        conversationUid: conversationUid
      );
    }
    return _chatMap[conversationUid]!;
  }

  ({bool isInsert}) addItem(ChatItem newItem, int insertIndex) {
    // 允许 msgId 为 null（本地乐观插入的消息还未收到后端 ACK）
    if (newItem.conversationUid == null ||
        newItem.senderUid == null) {
      return (isInsert: false);
    }
    // 此处需要构建新实例 而非复用旧的实例 newItem
    // 由于直接赋值是复制引用 所以后续的修改也会修改到原有的实例
    // 由于这个 ChatItem 我同时作用在两个表 一个 messageList 还有就是此处的 chatList 所以若是此处进行原有引用的修改 则会影响到 messageList
    ChatItem copyItem = ChatItem(
      uid: newItem.uid,
      nickname: newItem.nickname,
      avatarUrl: newItem.avatarUrl,
      conversationUid: newItem.conversationUid,
      content: newItem.content,
      senderUid: newItem.senderUid,
      msgId: newItem.msgId,
      requestId: newItem.requestId,
      sendStatus: newItem.sendStatus.value,
      isInsertToTop: newItem.isInsertToTop,
    );

    if (!_chatMap.containsKey(copyItem.conversationUid)) {
      _chatMap[copyItem.conversationUid!] = ConversationState(
        conversationUid: copyItem.conversationUid!
      );
    }
    RxList<ChatItem> list = _chatMap[copyItem.conversationUid]!.messageList;

    // 去重逻辑：优先用 msgId 去重，其次用 requestId 去重
    // 后端推送的消息有 msgId，前端临时消息只有 requestId
    // 当后端推送回消息时，需要用 requestId 找到前端临时消息并替换
    if (copyItem.msgId != null) {
      final existIndex = list.indexWhere((item) => item.msgId == copyItem.msgId);
      if (existIndex != -1) {
        return (isInsert: false);
      }
    }
    if (copyItem.requestId != null) {
      final existIndex = list.indexWhere((item) => item.requestId == copyItem.requestId);
      if (existIndex != -1) {
        // 找到前端临时消息，用后端消息替换（更新 msgId、sendStatus 等）
        list[existIndex] = copyItem;
        return (isInsert: false);
      }
    }
    // 兜底去重：如果后端推送的消息没有 requestId，但 content + senderUid 相同
    // 且是自己发送的消息，认为是同一条消息的重传（不限制状态，因为 ACK 可能先到）
    // 注意：历史消息（isInsertToTop=true）不应用此去重，因为历史消息中可能存在多条 content 相同的消息
    if (!copyItem.isInsertToTop &&
        copyItem.requestId == null &&
        copyItem.content != null &&
        copyItem.senderUid == userController.userInfo.value?.uid) {
      final existIndex = list.indexWhere((item) =>
          item.content == copyItem.content &&
          item.senderUid == copyItem.senderUid);
      if (existIndex != -1) {
        list[existIndex] = copyItem;
        return (isInsert: false);
      }
    }

    if (insertIndex == 0) {
      list.insert(0, copyItem);
    } else {
      list.add(copyItem);
    }

    return (isInsert: true);
  }

  void clear() {
    _chatMap.clear();
  }
}
