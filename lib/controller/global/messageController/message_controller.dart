import 'dart:async';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/categoryList/category_list.dart';
import 'package:chatapp/controller/global/messageController/chatList/chat_list.dart';
import 'package:chatapp/controller/global/messageController/messageList/message_list.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:get/get.dart';

/// 搜索结果列表操作事件
class SearchResultOperate extends ListEvent {
  final int index;
  final ListOperateType type;
  final dynamic item;
  SearchResultOperate({required this.type, required this.index, required this.item});
}

class MessageController extends GetxController {
  late final StreamSubscription<MessageBusEvent> _messageSub;

  late final MessageList messageList;
  late final CategoryList _categoryList;
  late final ChatList chatList;

  // ===== 挂起机制：看历史时对方消息暂不插入聊天列表 =====
  // 用户正在看历史（不在底部）时，若对方新消息插入底部，AnimatedList 的滚动行为
  // 会导致视角偏移/闪烁。因此当前活跃会话 + 不在底部时的对方消息先挂起，
  // 用户回到底部时由 chat_page 调用 flushPending 批量插入。
  String? _activeConversationUid; // 当前活跃聊天会话（由 chat_page 设置）
  bool _activeAtBottom = true; // 当前是否在列表底部（由 chat_page 同步）
  // 挂起的聊天消息：会话 uid -> 消息列表
  final Map<String, List<ChatItem>> _pendingChatItems = {};
  // 挂起消息计数（右下角"回到底部"按钮角标）
  final RxInt pendingNewMsgCount = 0.obs;

  /// chat_page 进入会话时设置活跃会话
  void setActiveConversation(String? conversationUid) {
    _activeConversationUid = conversationUid;
    _activeAtBottom = true;
    pendingNewMsgCount.value = 0;
  }

  /// chat_page 滚动时同步是否在底部
  void setActiveAtBottom(bool atBottom) {
    _activeAtBottom = atBottom;
  }

  /// 用户回到底部时调用：把挂起的消息批量插入聊天列表
  void flushPending(String conversationUid) {
    final pending = _pendingChatItems.remove(conversationUid);
    if (pending == null || pending.isEmpty) return;
    pendingNewMsgCount.value = 0;
    final state = chatList.getConversationState(conversationUid);
    for (final item in pending) {
      addChatItem(item, state.messageList.length);
    }
  }

  // 初始化时订阅消息分发总线的数据包装推送
  MessageController() {
    super.onInit();
    _messageSub = MessageDispatcher.instance.eventBus.listen((event) {
      if (event is MessageListEvent) {
        addMessageListItem(event.item);
        if (event.item is FriendApplyMessageItem) {
          FriendApplyMessageItem item = event.item as FriendApplyMessageItem;
          if (item.status == 1) {
            addCategoryItem("好友", item.uid, item.nickname, item.avatarUrl);
            deleteMessageListItem(item.uid);
          }
        } else if (event.item is ChatItem) {
          // 聊天消息渲染消息列表处的卡片的同时 也要渲染到聊天列表
          ChatItem item = event.item as ChatItem;
          // 看历史时（当前活跃会话 + 不在底部）对方新消息：挂起暂不插入列表，
          // 避免插入底部引起视角偏移/闪烁；用户回到底部时 flushPending 批量插入。
          final String myUid = Get.find<UserController>().uid;
          final bool isSelf = (item.senderUid ?? item.uid) == myUid;
          if (!item.isInsertToTop &&
              !isSelf &&
              _activeConversationUid != null &&
              _activeConversationUid == item.conversationUid &&
              !_activeAtBottom) {
            _pendingChatItems
                .putIfAbsent(item.conversationUid!, () => [])
                .add(item);
            pendingNewMsgCount.value++;
            return;
          }
          if (item.isInsertToTop ||
              chatList
                  .getConversationState(item.conversationUid!)
                  .messageList
                  .isEmpty) {
            addChatItem(item, 0);
          } else {
            addChatItem(
              item,
              chatList
                  .getConversationState(item.conversationUid!)
                  .messageList
                  .length,
            );
          }
        }
      } else if (event is CategoryListEvent) {
        if (event.info != null) {
          final CategoryInfo infoSnapShot = event.info!;
          if (infoSnapShot.isPullMoreItem) {
            // 获取更多分页数据
            if (infoSnapShot.type == 1) {
              final category = _categoryList.dataSource.firstWhereOrNull(
                (element) => element.name == event.info!.name,
              );
              if (category == null) return;

              unawaited(
                pullFriends(category.page, category.pageSize).then((result) {
                  // 获取新的分页数据之后 更新当前类别的页码以及 是否还有更多数据

                  final (:hasMore, :page, :friends) = result;
                  if (hasMore != null) {
                    category.hasMore = hasMore;
                  }
                  category.page = page;
                  if (friends != null && friends.isNotEmpty) {
                    for (var element in friends) {
                      final String? uid = element["uid"];
                      final String? nickname = element["nickname"];
                      final String? avatarUrl = element["avatarUrl"];
                      if (uid == null) continue;
                      addCategoryItem(
                        category.name,
                        uid,
                        nickname ?? "",
                        avatarUrl ?? "",
                      );
                    }
                  }
                }),
              );
            }
          } else {
            // 初始加载全部采用默认参数添加到列表
            addCategoryInfo(infoSnapShot);
            if (infoSnapShot.type == 1) {
              unawaited(
                pullFriends(infoSnapShot.page, infoSnapShot.pageSize).then((
                  result,
                ) {
                  // 获取新的分页数据之后 更新当前类别的页码以及 是否还有更多数据
                  final category = _categoryList.dataSource.firstWhereOrNull(
                    (element) => element.name == event.info!.name,
                  );
                  if (category == null) return;
                  final (:hasMore, :page, :friends) = result;
                  if (hasMore != null) {
                    category.hasMore = hasMore;
                  }
                  category.page = page;
                  if (friends != null && friends.isNotEmpty) {
                    for (var element in friends) {
                      final String? uid = element["uid"];
                      final String? nickname = element["nickname"];
                      final String? avatarUrl = element["avatarUrl"];
                      if (uid == null) continue;
                      addCategoryItem(
                        category.name,
                        uid,
                        nickname ?? "",
                        avatarUrl ?? "",
                      );
                    }
                  }
                }),
              );
            }
          }
        } else if (event.item != null) {}
      }
    });
    _categoryList = CategoryList();
    messageList = MessageList();
    chatList = ChatList();
    initMessagePage();
  }

  bool _isLoadingOfflineMessage = false;
  bool _isLoadingCategory = false;
  bool _isLoadingFriends = false;
  bool _isLoadingUnReadMessage = false;

  // 根据列表类型建立数据源映射
  Map<ListType, RxList<dynamic>> get dataSource => {
    ListType.messageList: messageList.dataSource,
    ListType.categoryItemList: _categoryList.dataSource,
  };

  // 操作事件监听流 外部根据事件执行动画
  final StreamController<ListEvent> _operateStream =
      StreamController.broadcast();
  Stream<ListEvent> get operateStream => _operateStream.stream;

  // 添加消息
  void addMessageListItem(BaseInfoItem newItem) {
    final bool isInsert = messageList.addItem(newItem);
    if (!isInsert) return;
    _operateStream.add(
      MessageListOperate(type: ListOperateType.insert, index: 0, item: newItem),
    );
  }

  // 删除消息
  void deleteMessageListItem(String targetUid) {
    final (:existIndex, :removeItem) = messageList.deleteItem(targetUid);
    if (existIndex == null || removeItem == null) return;
    // 将旧数据传输给删除事件，等待页面使用旧数据执行删除动画
    _operateStream.add(
      MessageListOperate(
        type: ListOperateType.remove,
        index: existIndex,
        item: removeItem,
      ),
    );

    // Future.delayed(
    //   const Duration(seconds: 5),
    //   () => infoList.removeAt(existIndex),
    // );
    // 这就是下一条消息被渲染成已删除的上一条消息的原因
  }

  // 添加分类
  void addCategoryInfo(CategoryInfo info) {
    final bool isInsert = _categoryList.addCategory(info);
    if (!isInsert) return;
    _operateStream.add(
      CategoryListOperate(type: ListOperateType.insert, index: 0, info: info),
    );
  }

  // 添加分类元素
  void addCategoryItem(
    String name,
    String uid,
    String nickname,
    String avatarUrl,
  ) {
    CategoryItem newItem = CategoryItem(
      uid: uid,
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
    final bool isInsert = _categoryList.addItem(name, newItem);
    if (!isInsert) return;
    _operateStream.add(
      CategoryListOperate(
        type: ListOperateType.insert,
        index: 0,
        item: newItem,
      ),
    );
  }

  // 添加聊天消息
  void addChatItem(ChatItem newItem, int insertIndex) {
    final (:isInsert) = chatList.addItem(newItem, insertIndex);
    if (!isInsert) return;
    _operateStream.add(
      ChatListOperate(
        type: ListOperateType.insert,
        index: insertIndex,
        item: newItem,
      ),
    );
  }

  // 删除聊天消息（本地删除，触发 CommonAnimatedList 删除动画）
  // 返回被删消息在数据源中的 index；未找到返回 -1
  int removeChatItem(ChatItem item) {
    final int index = chatList.removeItem(item);
    if (index == -1) return -1;
    _operateStream.add(
      ChatListOperate(
        type: ListOperateType.remove,
        index: index,
        item: item,
      ),
    );
    return index;
  }


  // 添加搜索结果项
  void addSearchResultItem(dynamic item, int index) {
    _operateStream.add(
      SearchResultOperate(type: ListOperateType.insert, index: index, item: item),
    );
  }

  // 删除搜索结果项
  void removeSearchResultItem(int index, dynamic item) {
    _operateStream.add(
      SearchResultOperate(type: ListOperateType.remove, index: index, item: item),
    );
  }
  // 初始化消息 及初始化拉取离线内容
  Future<void> initMessagePage() async {
    // 注意优先级顺序 若是先拉取离线好友请求
    // 当好友同意时会自动加到好友分类列表
    // 但是当前分类还没拉取 就会出现错误
    await pullCategory();
    await pullOfflineApply();
    await pullUnReadMessage();
  }

  Future<void> pullUnReadMessage() async {
    if (_isLoadingUnReadMessage) return;
    _isLoadingUnReadMessage = true;
    final CommonState commonState = await UserService.pullUnReadMessage();
    if (commonState.isSuccess && commonState.data != null) {
      List? messages = commonState.data["messages"];
      if (messages != null) {
        for (int i = 0; i < messages.length; i++) {
          MessageDispatcher.instance.dispatch(MessageDto.formJson(messages[i]));
        }
      }
    }
    _isLoadingUnReadMessage = false;
  }

  // 拉取离线好友请求
  Future<void> pullOfflineApply() async {
    if (_isLoadingOfflineMessage) return;
    _isLoadingOfflineMessage = true;
    final CommonState commonState = await UserService.pullOfflineApply();
    _isLoadingOfflineMessage = false;
    if (commonState.isSuccess && commonState.data != null) {
      if (commonState.data is List) {
        for (var element in commonState.data) {
          MessageDispatcher.instance.dispatch(MessageDto.formJson(element));
        }
      }
    }
  }

  // 拉取分类信息
  Future<void> pullCategory() async {
    if (_isLoadingCategory) return;
    _isLoadingCategory = true;
    final CommonState commonState = await UserService.pullCategory();
    if (commonState.isSuccess && commonState.data != null) {
      if (commonState.data is List) {
        for (var element in commonState.data) {
          Map<String, dynamic> data = Map.from({
            "msgType": "pullCategory",
            "data": element,
          });
          MessageDispatcher.instance.dispatch(MessageDto.formJson(data));
        }
      }
    }
    _isLoadingCategory = false;
  }

  // 拉取分类区域内部元素
  Future<({bool? hasMore, int page, List? friends})> pullFriends(
    int page,
    int pageSize,
  ) async {
    if (_isLoadingFriends) return (hasMore: null, page: page, friends: null);
    _isLoadingFriends = true;
    final CommonState commonState = await UserService.pullFriends(
      page,
      pageSize,
    );
    _isLoadingFriends = false;
    if (commonState.isSuccess && commonState.data != null) {
      bool? hasMore = commonState.data["hasMore"];
      int returnPage = commonState.data["page"] ?? page;
      List? friends = commonState.data["friends"];
      return (hasMore: hasMore, page: returnPage + 1, friends: friends);
    }

    return (hasMore: null, page: page, friends: null);
  }

  // 退出登录执行
  Future<void> clearInfo() async {
    chatList.clear();
    messageList.clear();
    _categoryList.clear();
  }

  @override
  void onClose() {
    _messageSub.cancel();
    _operateStream.close();
    super.onClose();
  }
}
