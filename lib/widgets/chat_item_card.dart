import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatItemCard extends StatefulWidget {
  final ChatItem item;
  final MainAxisAlignment axis;
  const ChatItemCard({super.key, required this.item, required this.axis});

  @override
  State<ChatItemCard> createState() {
    return _ChatItemCardState();
  }
}

class _ChatItemCardState extends State<ChatItemCard> {
  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final screenWidth = MediaQuery.of(context).size.width * 0.7;
    final AppTheme t = themeController.currentTheme;
    final bool isStartAlign = widget.axis == MainAxisAlignment.start;
    final List<Widget> childList = [
      Container(
        padding: EdgeInsets.all(5),
        constraints: BoxConstraints(
          minWidth: AppBase.chatCardItemHeight - 10,
          maxWidth: screenWidth,
          minHeight: AppBase.chatCardItemHeight - 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: t.secondColor,
        ),
        // IntrinsicWidth 强制子组件使用它内容本身的真实宽度
        child: IntrinsicWidth(
          child: Align(
            alignment: Alignment.center,
            child: Text(
              widget.item.content!,
              style: const TextStyle(fontSize: 30, color: Colors.black54),
              maxLines: null,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),

      SizedBox(width: 10),

      Container(
        margin: EdgeInsets.symmetric(
          horizontal: 6
        ),
        height: AppBase.chatCardItemHeight - 10,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: Image.network(
          buildStaticUrl(widget.item.avatarUrl),
          fit: BoxFit.cover,
        ),
      ),
    ];
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: widget.axis,
            children: [
              childList[isStartAlign ? 2 : 0],
              childList[1],
              childList[isStartAlign ? 0 : 2],
            ],
          ),
        ],
      ),
    );
  }
}
