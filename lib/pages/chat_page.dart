import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/messageController/chatList/chat_list.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/request_id_generator.dart';
import 'package:chatapp/widgets/chat_item_card.dart';
import 'package:chatapp/widgets/common_animated_list.dart';
import 'package:chatapp/widgets/message/card/chat_card.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() {
    return _ChatPageState();
  }
}

class _ChatPageState extends State<ChatPage> {
  late BaseInfoItem? _info;
  late MessageController _messageController;
  late ConversationState _conversationState;
  final TextEditingController _textEditingController = TextEditingController();
  bool _isArgumentLegal = false;
  bool _isLoadingHistory = false;
  bool _shouldScrollToBottom = false;
  RxDouble loadHistoryBox = 0.0.obs;

  Future<void> _loadHistory({
    String? cursorMsgId,
    required String conversationUid,
    int pageSize = 10,
  }) async {
    if (_isLoadingHistory || !_conversationState.hasMore) return;
    _isLoadingHistory = true;
    CommonState commonState = await UserService.pullMessage(
      pageSize,
      cursorMsgId,
      conversationUid,
    );
    if (commonState.isSuccess && commonState.data != null) {
      _conversationState.hasMore = commonState.data["hasMore"];
      List messages = commonState.data["messages"];
      for (int i = 0; i < messages.length; i++) {
        MessageDispatcher.instance.dispatch(MessageDto.formJson(messages[i]));
      }
    }
    _isLoadingHistory = false;
  }

  @override
  void initState() {
    super.initState();
    _messageController = Get.find<MessageController>();
    _info = Get.arguments;
    if (_info != null &&
        _info is ChatItem &&
        (_info as ChatItem).conversationUid != "") {
      _isArgumentLegal = true;
      _conversationState = _messageController.chatList.getConversationState(
        (_info as ChatItem).conversationUid!,
      );
      _loadHistory(conversationUid: (_info as ChatItem).conversationUid!);
    } else {
      _isArgumentLegal = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isArgumentLegal) {
      return Scaffold(body: Center(child: Text("页面参数异常")));
    }

    // 由于 _info == null 的情况已被上面拦截因此后续所有引用都添加 !
    ChatItem info = _info as ChatItem;
    double screenWidth = MediaQuery.of(context).size.width;
    double safeTopPadding = DeviceSize.instance.statusBarHeight;
    final themeController = Get.find<ThemeController>();
    final userController = Get.find<UserController>();
    final AppTheme t = themeController.currentTheme;
    final RxList<ChatItem> dataSource = _conversationState.messageList;
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        child: Container(
          color: t.backGroundColor,
          padding: EdgeInsets.fromLTRB(0, safeTopPadding, 0, 0),
          child: Column(
            children: [
              // 顶部操作栏
              Container(
                height: AppBase.topBarHeight,
                color: t.secondColor,
                padding: EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: Icon(Icons.arrow_back),
                    ),

                    Text(info.nickname),
                    IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
                  ],
                ),
              ),

              Obx(() {
                return AnimatedContainer(
                  height: loadHistoryBox.value,
                  decoration: BoxDecoration(color: t.backGroundColor),
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: Text(
                      _conversationState.hasMore ? "加载历史消息中..." : "已无更多消息",
                    ),
                  ),
                );
              }),

              Expanded(
                // 或者也可以使用 RefreshIndicator 来进行处理

                // NotificationListener 让子组件进行滑动时上报给父组件 与 GestureDetector 的区别在于 GestureDetector 的事件是从上往下分发 父->子 而 NotificationListener 的事件是从下往上分发 子-> 父
                // ScrollStartNotification	手指开始拖动 滚动开始
                // ScrollUpdateNotification	滚动过程中 持续每帧触发
                // ScrollEndNotification	滚动停止 手指松开 惯性滚动结束
                // OverscrollNotification	滚动越界（下拉回弹）

                // otification.metrics.pixels 当前滚动偏移量
                // notification.metrics.minScrollExtent 最小滚动位置（ListView头部边界）
                // notification.metrics.maxScrollExtent 最大滚动位置（ListView尾部边界）
                // notification.metrics.atEdge 是否已经滚到头部 or 尾部边界
                child: NotificationListener<ScrollNotification>(
                  // onNotification会极高频率执行 滚动一帧就调用一次
                  onNotification: (ScrollNotification notification) {
                    if (notification is OverscrollNotification) {
                      if (notification.overscroll < 0 &&
                          dataSource.isNotEmpty &&
                          _conversationState.hasMore) {
                        loadHistoryBox.value =
                            notification.overscroll.abs() * 30;
                      }
                    }
                    if (notification is ScrollEndNotification) {
                      if (loadHistoryBox.value > 0) {
                        const triggerThreshold = 80.0;
                        if (loadHistoryBox.value >= triggerThreshold &&
                            !_isLoadingHistory &&
                            _conversationState.hasMore) {
                          _loadHistory(
                            cursorMsgId: dataSource[0].msgId!,
                            conversationUid: info.conversationUid!,
                          );
                        }
                        loadHistoryBox.value = 0;
                      }
                    }
                    // true：拦截事件通知 不再让上层父组件接收
                    // false：事件通知继续向上冒泡 上层组件还可以接收 不拦截滚动
                    return false;
                  },
                  child: CommonAnimatedList(
                    scrollDirection: Axis.vertical,
                    type: ListType.chatList,
                    dataSource: dataSource,
                    eventPaser: (ListEvent event) {
                      if (event is ChatListOperate) {
                        return (
                          matched: true,
                          index: event.index,
                          operateType: event.type,
                          item: event.item,
                        );
                      }
                      return null;
                    },
                    insertItemBuilder: (item, animation) {
                      if (item is ChatItem) {
                        // 判断是不是自己发的消息
                        final bool isSelf = item.uid == userController.uid;
                        final offsetTween = isSelf
                            ? Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              )
                            : Tween<Offset>(
                                begin: const Offset(-1, 0),
                                end: Offset.zero,
                              );

                        return SlideTransition(
                          position: offsetTween.animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: ChatItemCard(
                              item: item,
                              axis: isSelf
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    deleteItemBuilder: (item, animation) {
                      return SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.vertical,
                        child: FadeTransition(
                          opacity: animation,
                          child: switch (item) {
                            ChatItem chatItem => ChatCard(
                              item: chatItem,
                              onDelete: () {},
                            ),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      );
                    },
                    controller: _messageController,
                    shouldAutoScrollBottom: () {
                      final val = _shouldScrollToBottom;
                      if (_shouldScrollToBottom) {
                        _shouldScrollToBottom = false;
                      }
                      return val;
                    },
                  ),
                ),
              ),

              Container(
                padding: EdgeInsets.all(10),
                width: screenWidth,
                height: 60,
                decoration: BoxDecoration(color: t.secondColor),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 7, 0),
                        decoration: BoxDecoration(
                          color: t.thirdColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: TextFormField(
                          maxLines: null,
                          controller: _textEditingController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Material(
                        color: t.secondColor,
                        borderRadius: BorderRadius.circular(5),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            WebSocketService.instance.sendDto(
                              MessageDto(
                                msgType: MessageType.chat,
                                requestId: RequestIdGenerator.generate(),
                                data: {
                                  "conversationUid": info.conversationUid,
                                  "receiverUid": info.uid,
                                  "content": _textEditingController.text,
                                },
                              ),
                            );
                            _shouldScrollToBottom = true;
                            _textEditingController.text = "";
                          },
                          splashColor: t.backGroundColor,
                          child: Icon(Icons.send, size: 35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
