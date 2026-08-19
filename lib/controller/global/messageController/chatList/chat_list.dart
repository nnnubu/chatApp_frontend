import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:get/get.dart';

class ChatListOperate extends ListEvent {
  final int index;
  final ListOperateType type;
  final BaseInfoItem item;
  ChatListOperate({
    required this.type,
    required this.index,
    required this.item,
  });
}

class ConversationState {
  final RxList<ChatItem> messageList;
  bool hasMore;
  ConversationState({this.hasMore = true}) : messageList = <ChatItem>[].obs;
}

class ChatList {
  // 以 conversationUid 为 key , 其中的 value 为该会话下的专用列表
  final RxMap<String, ConversationState> _chatMap = RxMap({});
  final UserController userController = Get.find<UserController>();

  ConversationState getConversationState(String conversationUid) {
    if (!_chatMap.containsKey(conversationUid)) {
      // _chatMap[conversationUid] = <ChatItem>[].obs;
      _chatMap[conversationUid] = ConversationState();
    }
    return _chatMap[conversationUid]!;
  }

  ({bool isInsert}) addItem(ChatItem newItem, int insertIndex) {
    if (newItem.conversationUid == null ||
        newItem.msgId == null ||
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
    );
    if (newItem.senderUid == userController.uid) {
      copyItem.uid = userController.uid;
      copyItem.nickname = userController.nickname;
      copyItem.avatarUrl = userController.avatar.url;
    }
    RxList<ChatItem> list = _chatMap[copyItem.conversationUid]!.messageList;

    final existIndex = list.indexWhere((item) => item.msgId == copyItem.msgId);
    if (existIndex != -1) {
      return (isInsert: false);
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
