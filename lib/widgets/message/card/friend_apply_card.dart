import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/utils/request_id_generator.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/pages/stranger_preview.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/widgets/message/item_info/message_list/friend_apply_item.dart';
import 'package:chatapp/widgets/message/slide_shell.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FriendApplyCard extends StatefulWidget {
  final FriendApplyMessageItem item;
  final VoidCallback onAgreeFriend;
  final VoidCallback onRefuseFriend;
  final VoidCallback onDelete;

  const FriendApplyCard({
    super.key,
    required this.item,
    required this.onAgreeFriend,
    required this.onRefuseFriend,
    required this.onDelete,
  });

  @override
  State<StatefulWidget> createState() {
    return _FriendApplyCardState();
  }
}

class _FriendApplyCardState extends State<FriendApplyCard> {
  final RxBool needResetSlide = false.obs;
  bool isMarked = false;

  void markRead(
    bool isReceiver,
    MessageType type,
    FriendApplyMessageItem info,
  ) {
    // 防止 点击和删除 操作 重复标记已读
    if (isMarked) return;
    // 发起者 并且已拒绝或已同意时才需要标记已读
    // 防止下次登录拉取未读好友请求错误
    if (!isReceiver && (type == MessageType.refuse || type == MessageType.argee)) {
      var markReadPackage = MessageDto(
        msgType: MessageType.markRead,
        requestId: RequestIdGenerator.generate(),
        msgId: info.msgId,
        data: {
          "readType": "friendApply",
        },
      );
      WebSocketService.instance.sendDto(markReadPackage);
      isMarked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FriendApplyMessageItem info = widget.item;
    final UserController userController = Get.find<UserController>();
    final bool isReceiver =
        info.getIdentity(userController.uid) == FriendOperateIdentity.receiver;
    return Obx(() {
      final type = widget.item.typeVal;
      final AppTheme t = Get.find<ThemeController>().currentTheme;
      final Color bgColor = switch (type) {
        MessageType.addFriend => t.secondColor,
        MessageType.refuse => t.forthColor,
        _ => t.backGroundColor,
      };
      return SlideShell(
        shelllAction: isReceiver && !type.isRefuse && !type.isAgree
            ? SizedBox(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: AppBase.messageCardItemHeight,
                        color: Colors.blueAccent,
                        child: TextButton(
                          onPressed: () {
                            needResetSlide.value = true;
                            widget.onAgreeFriend();
                          },
                          child: const Text(
                            "同意",
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: AppBase.messageCardItemHeight,
                        color: Colors.redAccent,
                        child: TextButton(
                          onPressed: () {
                            needResetSlide.value = true;
                            info.unReadCount.value = 0;
                            widget.onRefuseFriend();
                          },
                          child: const Text(
                            "拒绝",
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                height: AppBase.messageCardItemHeight,
                color: Colors.redAccent,
                child: TextButton(
                  onPressed: () {
                    needResetSlide.value = true;
                    widget.onDelete();
                    markRead(isReceiver, type, info);
                  },
                  child: const Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
        shellInChild: AnimatedContainer(
          color: bgColor,
          duration: const Duration(milliseconds: 800),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 头像
              GestureDetector(
                onTap: () {
                  Get.to(() => StrangerPreview(targetUid: info.uid));
                },
                child: Container(
                  width: AppBase.messageCardAvatarRadius,
                  height: AppBase.messageCardAvatarRadius,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.network(
                    buildStaticUrl(info.avatarUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: t.thirdColor,
                      child: Icon(Icons.person, color: t.hintTextColor),
                    ),
                  ),
                ),
              ),

              // 文字内容
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        info.nickname,
                        style: t.bodyStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.lastContent,
                        style: t.captionStyle.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // 右侧图标和未读计数
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (type == MessageType.addFriend)
                      Icon(
                        Icons.person_add_rounded,
                        size: 20,
                        color: t.primaryColor,
                      )
                    else if (type == MessageType.refuse)
                      Icon(
                        Icons.person_add_disabled_rounded,
                        size: 20,
                        color: t.hintTextColor,
                      ),
                    if (info.unReadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        height: 18,
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: t.errorColor,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            "${info.unReadCount > 99 ? "99+" : info.unReadCount}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        shellOnTap: () async {
          info.unReadCount.value = 0;
          markRead(isReceiver, type, info);
        },
        shellHeight: AppBase.messageCardItemHeight,
        actionWidth: isReceiver && !type.isRefuse && !type.isAgree
            ? AppBase.messageCardActionWidth * 2
            : AppBase.messageCardActionWidth,
        needReset: needResetSlide.value,
      );
    });
  }
}
