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
    // 实时发送消息时，后端推送发送者的基础消息 若发送者为自己 则修改渲染信息为自己的信息 若是让后端按发送者来返回信息的话 这个 MessageList 的消息卡片渲染就会出错 发一条消息同一个会话id就会显示自己的头像而不是接收者的头像 虽说可以靠判断来进行修改 但是对于初次渲染消息卡片时同样会出现这个问题 后续再想办法重构吧
    // if (newItem.senderUid == userController.uid) {
    //   copyItem.uid = userController.uid;
    //   copyItem.nickname = userController.nickname;
    //   copyItem.avatarUrl = userController.avatar.url;
    // }

    // 后端已经统一在发送消息时推送发送者的基础信息 消息列表的渲染问题后续再解决 此处问题已解决 在 message 界面进行了判断处理
    if (!_chatMap.containsKey(copyItem.conversationUid)) {
      // _chatMap[conversationUid] = <ChatItem>[].obs;
      _chatMap[copyItem.conversationUid!] = ConversationState();
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
