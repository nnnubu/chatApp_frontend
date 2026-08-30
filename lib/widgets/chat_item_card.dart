import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/widgets/app_image.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/ws/ack_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatItemCard extends StatefulWidget {
  final ChatItem item;
  final MainAxisAlignment axis;
  final VoidCallback? onResend; // 重发回调
  const ChatItemCard({super.key, required this.item, required this.axis, this.onResend});

  @override
  State<ChatItemCard> createState() {
    return _ChatItemCardState();
  }
}

class _ChatItemCardState extends State<ChatItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 直接访问 Rx 值，确保 Obx 能追踪到主题变化
      _themeController.currentType;
      final AppTheme t = _themeController.currentTheme;
      final screenWidth = MediaQuery.of(context).size.width * 0.7;
      final bool isSelf = widget.axis == MainAxisAlignment.end;

      // 不对称圆角：自己发的右上角小圆角，对方发的左上角小圆角
      final bubbleRadius = isSelf
          ? const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            );

      final bubble = GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _pressScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: screenWidth,
              minHeight: 36,
            ),
            decoration: BoxDecoration(
              borderRadius: bubbleRadius,
              color: isSelf ? t.primaryColor : t.secondColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IntrinsicWidth(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.item.content ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelf ? Colors.white : t.fontColor,
                    height: 1.4,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
        ),
      );

      final avatar = GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _pressScale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 36,
            height: 36,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: AppImage(
              imageUrl: widget.item.avatarUrl ?? '',
              width: 36,
              height: 36,
              type: AppImageType.avatar,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );

      return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: widget.axis,
          children: isSelf
              ? [
                  _StatusIndicator(item: widget.item, theme: t, onResend: widget.onResend),
                  const SizedBox(width: 4),
                  bubble,
                  const SizedBox(width: 8),
                  avatar
                ]
              : [avatar, const SizedBox(width: 8), bubble],
        ),
      );
    });
  }
}

/// 独立的状态指示器组件，自己管理 Obx，避免 sendStatus 变化时重建整个卡片
class _StatusIndicator extends StatelessWidget {
  final ChatItem item;
  final AppTheme theme;
  final VoidCallback? onResend;

  const _StatusIndicator({
    required this.item,
    required this.theme,
    this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = item.sendStatus.value;
      return _buildStatusIcon(status);
    });
  }

  Widget _buildStatusIcon(AckStatus status) {
    switch (status) {
      case AckStatus.pending:
      case AckStatus.retry:
        // retry 是内部自动重试状态，对外显示和 pending 一样转圈
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.hintTextColor),
          ),
        );
      case AckStatus.failed:
      case AckStatus.roamed:
        return GestureDetector(
          onTap: onResend,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.error_outline, size: 20, color: Colors.red.shade400),
          ),
        );
      case AckStatus.success:
        return Icon(
          Icons.check,
          size: 16,
          color: theme.hintTextColor.withOpacity(0.5),
        );
    }
  }
}
