import 'dart:io';

import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// 视频消息气泡
/// 显示视频首帧 + 中央播放按钮，点击全屏播放。
/// [localPath] 非空时加载本地视频（乐观渲染/上传失败阶段），否则加载网络视频。
class VideoBubble extends StatefulWidget {
  final String url; // 视频相对路径（网络 URL 或本地文件路径）
  final bool isSelf; // 是否自己发的（控制圆角方向）
  final String? localPath; // 本地文件路径

  const VideoBubble({
    super.key,
    required this.url,
    required this.isSelf,
    this.localPath,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  VideoPlayerController? _controller;
  final _initialized = false.obs;
  final _loadFailed = false.obs;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  /// url/localPath 变化时（如乐观渲染本地视频 -> 上传成功切换网络视频，
  /// 或列表复用 State 导致 widget 被替换），必须重建 controller，
  /// 否则会残留上一个视频的首帧/内容，出现多条视频显示相同的 bug。
  @override
  void didUpdateWidget(covariant VideoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.localPath != widget.localPath) {
      _resetController();
    }
  }

  Future<void> _resetController() {
    _controller?.dispose();
    _controller = null;
    _initialized.value = false;
    _loadFailed.value = false;
    return _initController();
  }

  Future<void> _initController() async {
    try {
      final VideoPlayerController ctrl;
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        ctrl = VideoPlayerController.file(File(widget.localPath!));
      } else {
        ctrl = VideoPlayerController.networkUrl(
          Uri.parse(buildStaticUrl(widget.url)),
        );
      }
      _controller = ctrl;
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _initialized.value = true;
    } catch (e) {
      debugPrint('视频加载失败: $e');
      _loadFailed.value = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 全屏播放
  void _playFullscreen() {
    final ctrl = _controller;
    if (ctrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        ctrl.setLooping(false);
        ctrl.seekTo(Duration.zero);
        ctrl.play();
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    ctrl.pause();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxW = MediaQuery.of(context).size.width * 0.5;
    final double width = maxW > 220 ? 220 : maxW;

    // 圆角：自己发的右上角小圆角，对方发的左上角小圆角
    final BorderRadius radius = widget.isSelf
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

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: 150,
        color: Colors.black87,
        child: Obx(() => _loadFailed.value
            ? const Center(
                child: Icon(Icons.videocam_off_outlined,
                    color: Colors.white54, size: 32),
              )
            : !_initialized.value
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _playFullscreen,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: _controller!.value.size.width,
                              height: _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                        // 中央播放按钮
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        // 时长角标
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(
                                  _controller!.value.duration.inSeconds),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
