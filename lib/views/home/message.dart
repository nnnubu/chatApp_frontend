import 'dart:async';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/messageController/categoryList/category_list.dart';
import 'package:chatapp/controller/global/messageController/messageList/message_list.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/dto/dto_others.dart';
import 'package:chatapp/pages/stranger_preview.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/common_animated_list.dart';
import 'package:chatapp/widgets/message/card/chat_card.dart';
import 'package:chatapp/widgets/message/card/friend_apply_card.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:chatapp/widgets/wave_container.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:chatapp/ws/heart_beat.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

const Color _upperContentColor = Colors.black;
const double _upperContentSize = 20;

class MessageView extends StatefulWidget {
  const MessageView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MessageView();
  }
}

class _MessageView extends State<MessageView>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late AnimationController _iconAnimCtrl;
  late ThemeController _themeController;
  late MessageController _messageController;
  final RxBool _isSubmitting = false.obs;
  final RxInt categoryItemIndex = 0.obs;
  final RxBool isMenuOpen = false.obs;
  final RxBool isTopSlideOpen = false.obs;
  final RxList<dynamic> _emptyRxList =
      <dynamic>[].obs; // 兜底用空列表 防止 key 重复变换引用触发重建
  final RxBool _isSearching = false.obs;
  final RxString _searchKeyword = ''.obs;
  final RxList<dynamic> _searchResults = <dynamic>[].obs;
  final GlobalKey<AnimatedListState> _searchListKey = GlobalKey<AnimatedListState>();
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();

  Future<void> updateApply(FriendApplyMessageItem item, bool isAgree) async {
    if (_isSubmitting.value) return;
    try {
      final String msgId = item.msgId;
      _isSubmitting.value = true;
      CommonState commonState = await UserService.updateApply(msgId, isAgree);

      showTipSnackbar(msg: commonState.msg, isSuccess: commonState.isSuccess);
    } finally {
      if (mounted) {
        _isSubmitting.value = false;
      }
    }
  }

  void _deleteItem(String targetUid) {
    _messageController.deleteMessageListItem(targetUid);
  }

  void _onSearchChanged(String value) {
    _searchKeyword.value = value;
    if (_searchDebounce != null) {
      _searchDebounce!.cancel();
    }
    if (value.trim().isEmpty) {
      _isSearching.value = false;
      _clearSearchResults();
      return;
    }
    _isSearching.value = true;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _doSearch(value.trim());
    });
  }

  void _clearSearchResults() {
    // 从后往前推送删除事件
    for (int i = _searchResults.length - 1; i >= 0; i--) {
      final item = _searchResults[i];
      _searchResults.removeAt(i);
      _messageController.removeSearchResultItem(i, item);
    }
  }

  Future<void> _doSearch(String keyword) async {
    try {
      debugPrint('搜索关键词: $keyword');
      final results = await UserService.searchFriends(keyword);
      debugPrint('搜索结果数量: ${results?.length ?? 0}');
      _clearSearchResults();
      _isSearching.value = false;
      if (results != null && results.isNotEmpty) {
        // 等高度动画完成（300ms）+ 一帧，确保 AnimatedList 已渲染
        await Future.delayed(const Duration(milliseconds: 350));
        debugPrint('开始插入搜索结果，当前 _searchResults 长度: ${_searchResults.length}');
        for (int i = 0; i < results.length; i++) {
          _searchResults.add(results[i]);
          _messageController.addSearchResultItem(results[i], i);
          debugPrint('插入搜索结果 index=$i, name=${results[i].nickname}');
        }
        debugPrint('插入完成，_searchResults 长度: ${_searchResults.length}');
      }
    } catch (e) {
      debugPrint('搜索失败: $e');
      _isSearching.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _iconAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _themeController = Get.find<ThemeController>();
    _messageController = Get.find<MessageController>();
  }

  @override
  void dispose() {
    _iconAnimCtrl.dispose();
    super.dispose();
  }

  // 页面切换保持组件存活，否则会丢失当前滑到哪个位置
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    double safeTopPadding = DeviceSize.instance.statusBarHeight;
    double screenWidth = MediaQuery.of(context).size.width;

    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      final exhausted = WebSocketService.instance.autoReconnectExhausted.value;
      final manualReconnecting =
          WebSocketService.instance.isManuallyReconnecting.value;
      final categoryInfoList =
          _messageController.dataSource[ListType.categoryItemList] ?? [];
      final RxList<dynamic> categoryItemList = categoryInfoList.isEmpty
          ? _emptyRxList
          : categoryInfoList[categoryItemIndex.value].itemList;
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // 网络错误 手动重连入口
            Obx(() {
              final exhausted = WebSocketService.instance.autoReconnectExhausted.value;
              final manualReconnecting = WebSocketService.instance.isManuallyReconnecting.value;
              final backendReady = WebSocketService.instance.backendReady.value;
              final health = WebSocketService.instance.connectionHealth.value;
              final Color barColor;
              final String barText;
              final bool showSpinner;
              if (manualReconnecting && !backendReady) {
                barColor = Colors.orange;
                barText = "正在连接服务器…";
                showSpinner = true;
              } else if (manualReconnecting && backendReady && health == ConnectionHealth.unconfirmed) {
                barColor = Colors.blue;
                barText = "正在检测链路健康…";
                showSpinner = true;
              } else {
                barColor = Colors.red;
                barText = "当前无网络，点击重新连接";
                showSpinner = false;
              }
              return AnimatedContainer(
                color: t.backGroundColor,
                duration: const Duration(milliseconds: 800),
                height: manualReconnecting || exhausted ? 90 : 0,
                padding: EdgeInsets.fromLTRB(0, safeTopPadding, 0, 0),
                child: Container(
                  color: barColor,
                  child: showSpinner
                      ? Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                barText,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : InkWell(
                          onTap: () {
                            WebSocketService.instance.manualReconnect();
                          },
                          child: SizedBox.expand(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  barText,
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(width: 5),
                                Icon(
                                  Icons.restart_alt_sharp,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            }),

            // 搜索栏
            Container(
              color: t.secondColor,
              padding: EdgeInsets.fromLTRB(
                3,
                manualReconnecting || exhausted ? 0 : safeTopPadding,
                0,
                0,
              ),
              child: Row(
                children: [
                  Container(
                    margin: EdgeInsets.all(5),
                    height: AppBase.topBarHeight,
                    width: screenWidth - AppBase.menuIconWidth,
                    decoration: BoxDecoration(
                      color: t.thirdColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextFormField(
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "搜索",
                        // contentPadding: EdgeInsets.symmetric(
                        //   horizontal: 5,
                        //   vertical: 10,
                        // ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        suffixIcon: _searchKeyword.value.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchKeyword.value = '';
                                  _clearSearchResults();
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : const Icon(Icons.search),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PopupMenuButton(
                      offset: const Offset(0, AppBase.topBarHeight + 4),
                      padding: EdgeInsets.zero,
                      onOpened: () {
                        isMenuOpen.value = true;
                        _iconAnimCtrl.forward();
                      },
                      onCanceled: () {
                        isMenuOpen.value = false;
                        _iconAnimCtrl.reverse();
                      },
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _iconAnimCtrl,
                      ),
                      color: t.backGroundColor,
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          onTap: () async {
                            var status = await Permission.camera.request();
                            if (status.isDenied) {
                              Get.snackbar("权限不足", "需要相机权限才能扫码");
                              return;
                            }
                            Get.toNamed("/scanQR");
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 18),
                              const SizedBox(width: 8),
                              const Text("添加好友"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () async {
                            debugPrint("点击了添加分类");
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 18),
                              const SizedBox(width: 8),
                              const Text("添加消息分类"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (categoryInfoList.isNotEmpty)
              // 顶部分类栏 波浪动画
              WaveContainer(
                waveDepth: 45,
                waveLength: 160,
                orderTab: categoryItemIndex.value,
                isConcave: false,
                isActive: isTopSlideOpen.value,
                underBgColor: t.backGroundColor,
                upperBgColor: t.secondColor,
                onTabChange: (int index) {
                  categoryItemIndex.value = index;
                },
                onActive: (bool isActive) {
                  isTopSlideOpen.value = isActive;
                },
                upperContent: categoryInfoList.map((info) {
                  if (info is CategoryInfo) {
                    return Text(
                      info.name,
                      style: TextStyle(
                        color: t.fontColor,
                        fontSize: _upperContentSize - 5,
                      ),
                    );
                  } else {
                    return ColoredBox(color: t.secondColor);
                  }
                }).toList(),
              )
            else
              Container(
                height: 45,
                color: t.backGroundColor,
                child: Center(child: Text("分类信息获取失败")),
              ),
            // 分类具体内容
            GestureDetector(
              onVerticalDragEnd: (details) {
                double vy = details.velocity.pixelsPerSecond.dy;
                if (vy < -100) {
                  isTopSlideOpen.value = false;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: isTopSlideOpen.value ? AppBase.topSlideHeight : 0,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.backGroundColor,
                  border: Border(bottom: BorderSide(color: t.secondColor)),
                ),
                child: CommonAnimatedList(
                  // 以数据源为 key 当数据源引用发生变化时销毁重建 防止内部动画条目的复用
                  key: ValueKey(categoryItemList),
                  type: ListType.categoryItemList,
                  eventPaser: (ListEvent event) {
                    if (event is CategoryListOperate && event.item != null) {
                      return (
                        matched: true,
                        index: event.index,
                        operateType: event.type,
                        item: event.item!,
                      );
                    }
                    return null;
                  },
                  insertItemBuilder: (item, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: FadeTransition(
                        opacity: animation,
                        child: InkWell(
                          onTap: () {
                            Get.to(() => StrangerPreview(targetUid: item.uid));
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                margin: const EdgeInsets.all(5),
                                clipBehavior: Clip.hardEdge,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: Image.network(
                                  buildStaticUrl(item.avatarUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) {
                                    return Container(
                                      color: t.thirdColor,
                                      child: Icon(Icons.person, color: t.hintTextColor),
                                    );
                                  },
                                ),
                              ),
                              if (item.isOnline)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    height: AppBase.onlineRadius,
                                    width: AppBase.onlineRadius,
                                    decoration: BoxDecoration(
                                      color: AppBase.onlineSign,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  deleteItemBuilder: (item, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: FadeTransition(
                        opacity: animation,
                        child: Container(
                          width: 55,
                          height: 55,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Image.network(
                            buildStaticUrl(item.avatarUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return const Icon(Icons.person);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onPlayAnimation: () async {
                    isTopSlideOpen.value = true;
                  },
                  messageController: _messageController,
                  themeController: _themeController,
                  dataSource: categoryItemList,
                  scrollDirection: Axis.horizontal,
                ),
              ),
            ),

            // 消息栏
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: t.backGroundColor,
                    child: CommonAnimatedList(
                  type: ListType.messageList,
                  dataSource:
                      _messageController.dataSource[ListType.messageList] ??
                      [].obs,
                  eventPaser: (ListEvent event) {
                    if (event is MessageListOperate) {
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
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.vertical,
                      child: FadeTransition(
                        opacity: animation,
                        child: switch (item) {
                          ChatItem chatItem => Builder(
                            builder: (context) {
                              // 由于后端统一发送发送者的基础信息 因此对于自己这边发送消息时 优先在分类区域寻找指定的聊天对象 获取其基础 信息并覆盖 注意不要使用原有的 chatItem ，而是拷贝一个，否则会修改到聊天界面的chatItem信息 毕竟两者是同一个实例引用
                              BaseInfoItem? receiverInfo;
                              ChatItem copyItem = chatItem;
                              if (categoryInfoList.isNotEmpty) {
                                for (final dynamic raw in categoryInfoList) {
                                  if (raw is CategoryInfo) {
                                    receiverInfo = raw.itemList.firstWhereOrNull((e) => e.uid == item.receiverUid);
                                    if (receiverInfo != null) {
                                      break;
                                    }
                                  }
                                }
                                if (receiverInfo != null) {
                                  copyItem.uid = receiverInfo.uid;
                                  copyItem.nickname = receiverInfo.nickname;
                                  copyItem.avatarUrl = receiverInfo.avatarUrl;
                                }
                              }
                              return ChatCard(
                                // key: ValueKey(item.uid),
                                // 可以使用 key 让其不复用索引缓存 只要卡片内部数据出现 任何变化 都会销毁重建
                                // 此处就不复用了，否则在删除卡片的时候会让我原本封装的滑动动画位置不被使用，进而出现滑动出来点击删除按钮的时候不是动画滑动回原点，而是直接闪现到原点
                                item: copyItem,
                                onDelete: () => _deleteItem(item.uid),
                              );
                            },
                          ),
                          FriendApplyMessageItem friendApplyItem =>
                            FriendApplyCard(
                              item: friendApplyItem,
                              onAgreeFriend: () =>
                                  updateApply(friendApplyItem, true),
                              onRefuseFriend: () =>
                                  updateApply(friendApplyItem, false),
                              onDelete: () => _deleteItem(item.uid),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    );
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
                          FriendApplyMessageItem friendApplyItem =>
                            FriendApplyCard(
                              item: friendApplyItem,
                              onAgreeFriend: () {},
                              onRefuseFriend: () {},
                              onDelete: () {},
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    );
                  },
                  messageController: _messageController,
                  themeController: _themeController,
                  scrollDirection: Axis.vertical,
                  ),
                ),
                // 搜索结果覆盖层 AnimatedContainer 高度变化
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Obx(() {
                    final showSearch = _searchKeyword.value.trim().isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: showSearch ? 400 : 0,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Positioned.fill(child: Container(color: t.thirdColor)),
                            CommonAnimatedList(
                                      type: ListType.searchResultList,
                                      messageController: _messageController,
                                      themeController: _themeController,
                                      dataSource: _searchResults,
                                      scrollDirection: Axis.vertical,
                                      eventPaser: (ListEvent event) {
                                        if (event is SearchResultOperate) {
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
                                        final user = item as OtherUsers;
                                        return SizeTransition(
                                          sizeFactor: animation,
                                          child: InkWell(
                                            onTap: () {
                                              Get.to(() => StrangerPreview(targetUid: user.uid));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundImage: NetworkImage(buildStaticUrl(user.avatar.url)),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                user.nickname,
                                                                style: t.bodyStyle,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (user.isFriend) ...[
                                                              const SizedBox(width: 8),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: t.primaryColor.withOpacity(0.15),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: Text(
                                                                  "已添加",
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: t.primaryColor,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          user.intro.isEmpty ? "这个人很懒，什么都没写" : user.intro,
                                                          style: t.captionStyle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(Icons.chevron_right, color: t.hintTextColor, size: 20),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      deleteItemBuilder: (item, animation) {
                                        return SizeTransition(
                                          sizeFactor: animation,
                                          child: const SizedBox.shrink(),
                                        );
                                      },
                                    ),
                            if (_isSearching.value)
                              Container(
                                color: t.thirdColor.withOpacity(0.8),
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
        ),
      );
    });
  }
}
