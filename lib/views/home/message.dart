import 'dart:async';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/messageController/categoryList/category_list.dart';
import 'package:chatapp/controller/global/messageController/messageList/message_list.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/pages/stranger_preview.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/common_animated_list.dart';
import 'package:chatapp/widgets/message/card/chat_card.dart';
import 'package:chatapp/widgets/message/card/friend_apply_card.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:chatapp/widgets/wave_container.dart';
import 'package:chatapp/ws/websocket_service.dart';
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
            AnimatedContainer(
              color: t.backGroundColor,
              duration: const Duration(milliseconds: 800),
              height: exhausted ? 90 : 0,
              padding: EdgeInsets.fromLTRB(0, safeTopPadding, 0, 0),
              child: Container(
                color: Colors.red,
                child: manualReconnecting
                    ? const Center(
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
                              "正在尝试重连…",
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
                            children: const [
                              Text(
                                "当前无网络，点击重新连接",
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
            ),

            // 搜索栏
            Container(
              color: t.secondColor,
              padding: EdgeInsets.fromLTRB(
                3,
                exhausted ? 0 : safeTopPadding,
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
                      onFieldSubmitted: (String value) {
                        debugPrint("点击了搜索");
                        FocusScope.of(context).unfocus();
                      },
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
                        suffixIcon: const Icon(Icons.search),
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
                        color: _upperContentColor,
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
                                width: 55,
                                height: 55,
                                margin: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
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
                  controller: _messageController,
                  dataSource: categoryItemList,
                  scrollDirection: Axis.horizontal,
                ),
              ),
            ),

            // 消息栏
            Expanded(
              child: Container(
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
                          ChatItem chatItem => ChatCard(
                            // key: ValueKey(item.uid),
                            // 可以使用 key 让其不复用索引缓存 只要卡片内部数据出现 任何变化 都会销毁重建
                            // 此处就不复用了，否则在删除卡片的时候会让我原本封装的滑动动画位置不被使用，进而出现滑动出来点击删除按钮的时候不是动画滑动回原点，而是直接闪现到原点
                            item: chatItem,
                            onDelete: () => _deleteItem(item.uid),
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
                  controller: _messageController,
                  scrollDirection: Axis.vertical,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
