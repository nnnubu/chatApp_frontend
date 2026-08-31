import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/pages/stranger_preview.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/slide_shell.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatCard extends StatefulWidget {
  final ChatItem item;
  final VoidCallback onDelete;
  final bool autoSlideBack;

  const ChatCard({super.key, required this.item, required this.onDelete, this.autoSlideBack = false});

  @override
  State<ChatCard> createState() {
    return _ChatCardState();
  }
}

class _ChatCardState extends State<ChatCard> {
  // 控制卡片删除后回弹，否则可能会被复用卡片的移动状态
  final RxBool needResetSlide = false.obs;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ChatItem info = widget.item;
    return Obx(() {
      final AppTheme t = Get.find<ThemeController>().currentTheme;
      return SlideShell(
        shellHeight: AppBase.messageCardItemHeight,
        actionWidth: AppBase.messageCardActionWidth,
        shelllAction: Container(
          height: AppBase.messageCardItemHeight,
          color: Colors.redAccent,
          child: TextButton(
            onPressed: () {
              needResetSlide.value = true;
              widget.onDelete();
            },
            child: const Icon(Icons.delete, size: 20, color: Colors.white),
          ),
        ),

        shellInChild: AnimatedContainer(
          color: t.backGroundColor,
          duration: const Duration(milliseconds: 800),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                        info.content ?? "",
                        style: t.captionStyle.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // 右侧未读计数（胶囊形）
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
          Get.to(() => ChatPage(),arguments: info);
        },
        needReset: needResetSlide.value,
        autoSlideBack: widget.autoSlideBack,
      );
    });
  }
}
