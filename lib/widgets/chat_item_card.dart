import 'dart:io';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/app_image.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/image_message.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/voice_message.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/video_message.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/sticker_message.dart';
import 'package:chatapp/widgets/voice_bubble.dart';
import 'package:chatapp/widgets/video_bubble.dart';
import 'package:chatapp/ws/ack_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatItemCard extends StatefulWidget {
  final ChatItem item;
  final MainAxisAlignment axis;
  final VoidCallback? onResend; // 重发回调
  final VoidCallback? onDelete; // 删除回调（长按菜单）
  final VoidCallback? onRecall; // 撤回回调（长按菜单，仅自己发且未撤回）
  const ChatItemCard({
    super.key,
    required this.item,
    required this.axis,
    this.onResend,
    this.onDelete,
    this.onRecall,
  });

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

  /// 已撤回消息：居中灰色提示文字，不带气泡背景（微信风格）
  Widget _buildRecalledBubble(AppTheme t, bool isSelf) {
    return Text(
      isSelf ? '你撤回了一条消息' : '对方撤回了一条消息',
      style: TextStyle(
        fontSize: 12,
        color: t.hintTextColor,
        height: 1.4,
      ),
    );
  }

  /// 气泡内容构建：文本 / 图片 / 视频 分支
  Widget _buildBubbleContent(ChatItem item, AppTheme t, bool isSelf,
      double maxWidth, BorderRadius bubbleRadius) {
    // ===== 视频消息分支（优先判断，避免视频 JSON 因含 url 字段被误判为图片）=====
    if (item.contentType == ContentType.video.code) {
      final VideoMessageContent? video =
          VideoMessageContent.tryParse(item.content);
      if (video != null) {
        // content 解析成功（已上传）：显示网络视频气泡
        return VideoBubble(
          key: ValueKey('video_net_${video.url}'),
          url: video.url,
          isSelf: isSelf,
        );
      }
      // content 未解析成功（上传中/上传失败）：
      // 本地视频文件仍在，显示本地视频占位（可试播）
      if (item.localVideoPath != null && item.localVideoPath!.isNotEmpty) {
        return VideoBubble(
          key: ValueKey('video_local_${item.localVideoPath}'),
          url: item.localVideoPath!,
          isSelf: isSelf,
          localPath: item.localVideoPath,
        );
      }
      // 既无 content 也无本地文件（极端情况）：显示失败占位
      final bool videoUploadFailed =
          item.sendStatus.value == AckStatus.roamed;
      return Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: isSelf ? t.primaryColor : t.secondColor,
          borderRadius: bubbleRadius,
        ),
        child: Center(
          child: videoUploadFailed
              ? const Icon(Icons.error_outline, size: 20, color: Colors.white)
              : const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    }

    // ===== 表情包消息分支：直接引用已收藏的表情包 url，无上传过程 =====
    if (item.contentType == ContentType.sticker.code) {
      final StickerMessageContent? sticker =
          StickerMessageContent.tryParse(item.content);
      if (sticker != null) {
        return AppImage(
          imageUrl: sticker.url,
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          type: AppImageType.general,
        );
      }
      // content 解析失败（极端情况）：显示占位
      return const SizedBox(
        width: 120,
        height: 120,
        child: Icon(Icons.broken_image_outlined, size: 32),
      );
    }

    // ===== 语音消息分支（优先判断，避免语音 JSON 因含 url 字段被误判为图片）=====
    if (item.contentType == ContentType.voice.code) {
      final VoiceMessageContent? voice = VoiceMessageContent.tryParse(item.content);
      if (voice != null) {
        // content 解析成功（已上传）：显示网络语音气泡
        return VoiceBubble(
          url: voice.url,
          duration: voice.duration,
          isSelf: isSelf,
        );
      }
      // content 未解析成功（上传中/上传失败）：
      // 若本地录音文件仍在，显示语音气泡用于本地预览播放（无需等上传到后端）
      if (item.localVoicePath != null && item.localVoicePath!.isNotEmpty) {
        return VoiceBubble(
          url: item.localVoicePath!,
          duration: item.localVoiceDuration.toDouble(),
          isSelf: isSelf,
          localPath: item.localVoicePath,
        );
      }
      // 既无 content 也无本地文件（极端情况）：显示失败占位
      final bool voiceUploadFailed =
          item.sendStatus.value == AckStatus.roamed;
      return Container(
        width: 90,
        height: 40,
        decoration: BoxDecoration(
          color: isSelf ? t.primaryColor : t.secondColor,
          borderRadius: bubbleRadius,
        ),
        child: Center(
          child: voiceUploadFailed
              ? const Icon(Icons.error_outline, size: 20, color: Colors.white)
              : const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    }

    // 图片消息：优先解析网络 URL
    final img = ImageMessageContent.tryParse(item.content);
    if (img != null) {
      return ClipRRect(
        borderRadius: bubbleRadius,
        child: GestureDetector(
          onTap: () => _showImagePreview(img),
          child: AppImage(
            imageUrl: img.thumb,
            width: _calcImageWidth(img, maxWidth),
            height: _calcImageHeight(img, maxWidth),
            fit: BoxFit.cover,
            type: AppImageType.general,
          ),
        ),
      );
    }
    // 图片消息但 content 未解析成功：上传中/上传失败阶段，显示本地选图
    if (item.contentType == ContentType.image.code &&
        item.localImagePath != null &&
        item.localImagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: bubbleRadius,
        child: Image.file(
          File(item.localImagePath!),
          width: _calcLocalImageWidth(maxWidth),
          height: _calcLocalImageHeight(maxWidth),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            width: _calcLocalImageWidth(maxWidth),
            height: _calcLocalImageHeight(maxWidth),
            color: t.thirdColor,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }
    // 文本消息
    return IntrinsicWidth(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item.content ?? '',
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
    );
  }

  /// 图片展示宽度：限制最大宽 220，按原图比例
  double _calcImageWidth(ImageMessageContent img, double maxWidth) {
    if (img.width <= 0 || img.height <= 0) return 200;
    const maxW = 220.0;
    const maxH = 240.0;
    final ratio = img.width / img.height;
    double w = maxW;
    double h = w / ratio;
    if (h > maxH) {
      h = maxH;
      w = h * ratio;
    }
    return w > maxWidth ? maxWidth : w;
  }

  double _calcImageHeight(ImageMessageContent img, double maxWidth) {
    if (img.width <= 0 || img.height <= 0) return 200;
    final w = _calcImageWidth(img, maxWidth);
    return w / (img.width / img.height);
  }

  // 本地图片（上传中）默认固定 200x200 占位尺寸
  double _calcLocalImageWidth(double maxWidth) {
    return 200 > maxWidth ? maxWidth : 200;
  }

  double _calcLocalImageHeight(double maxWidth) {
    return 200 > maxWidth ? maxWidth : 200;
  }

  /// 长按气泡弹出操作菜单（删除/撤回，供后续扩展）
  void _showMessageActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 操作项：撤回（仅自己发的 且 未撤回）
              if (widget.axis == MainAxisAlignment.end &&
                  !widget.item.recalled.value)
                ListTile(
                  leading: Icon(Icons.reply, color: _themeController.currentTheme.primaryColor),
                  title: const Text('撤回'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onRecall?.call();
                  },
                ),
              // 删除
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete?.call();
                },
              ),
              // 取消
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 点击图片全屏预览
  void _showImagePreview(ImageMessageContent img) {    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: AppImage(
                  imageUrl: img.url,
                  width: MediaQuery.of(ctx).size.width,
                  fit: BoxFit.contain,
                  type: AppImageType.general,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 直接访问 Rx 值，确保 Obx 能追踪到主题变化
      _themeController.currentType;
      // 监听内容版本号：图片上传完成后 content 更新，触发气泡从本地图切换到网络图
      widget.item.contentVersion;
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

      final bool isImage = widget.item.contentType == ContentType.image.code;
      // 语音/图片/视频消息使用紧凑 padding，避免固定高度气泡 + 外层 padding 叠加溢出
      final bool isMediaBubble = isImage ||
          widget.item.contentType == ContentType.voice.code ||
          widget.item.contentType == ContentType.video.code ||
          widget.item.contentType == ContentType.sticker.code;
      // 已撤回：不展示原内容，替换为灰色提示文字（仍可长按删除）
      final bool isRecalled = widget.item.recalled.value;
      final Widget bubble = isRecalled
          ? GestureDetector(
              onLongPress: _showMessageActions,
              child: _buildRecalledBubble(t, isSelf),
            )
          : GestureDetector(
              onTapDown: (_) => _pressController.forward(),
              onTapUp: (_) => _pressController.reverse(),
              onTapCancel: () => _pressController.reverse(),
              onLongPress: _showMessageActions,
              child: ScaleTransition(
                scale: _pressScale,
                child: Container(
                  padding: isMediaBubble
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: screenWidth,
                    minHeight: 36,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: bubbleRadius,
                    color: isMediaBubble ? Colors.transparent : (isSelf ? t.primaryColor : t.secondColor),
                    boxShadow: isMediaBubble
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: _buildBubbleContent(widget.item, t, isSelf, screenWidth, bubbleRadius),
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
                  // 已撤回消息不显示发送状态指示器
                  if (!isRecalled)
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
