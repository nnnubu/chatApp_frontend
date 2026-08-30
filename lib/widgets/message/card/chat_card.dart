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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Get.to(() => StrangerPreview(targetUid: info.uid));
                },
                child: Container(
                  width: AppBase.messageCardAvatarRadius,
                  height: AppBase.messageCardAvatarRadius,
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Image.network(
                    buildStaticUrl(info.avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            info.nickname,
                            style: t.bodyStyle.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            info.content ?? "",
                            style: t.captionStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Positioned(
                        right: 10,
                        top: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(height: 25),
                            if (info.unReadCount > 0)
                              Container(
                                height: 19,
                                width: 19,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "${info.unReadCount > 99 ? "99+" : info.unReadCount}",
                                    style: TextStyle(
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
