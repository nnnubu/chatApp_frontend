import 'dart:io';

import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// 视频消息气泡
/// 有 [thumbUrl]（后端 ffmpeg 抽帧缩略图）：直接显示缩略图（走图片缓存，不转圈），
/// 点击**立即进入全屏播放器**，加载转圈在全屏内显示，加载完成自动播放。
/// 无 [thumbUrl]（旧消息 / 乐观渲染本地视频）：保持旧逻辑，进入即初始化视频显示首帧。
/// [localPath] 非空时加载本地视频（乐观渲染/上传失败阶段），否则加载网络视频。
class VideoBubble extends StatefulWidget {
  final String url; // 视频相对路径（网络 URL 或本地文件路径）
  final bool isSelf; // 是否自己发的（控制圆角方向）
  final String? localPath; // 本地文件路径
  final String? thumbUrl; // 视频缩略图 URL（网络视频时可能为空）

  const VideoBubble({
    super.key,
    required this.url,
    required this.isSelf,
    this.localPath,
    this.thumbUrl,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  VideoPlayerController? _controller;
  final _initialized = false.obs;
  final _loadFailed = false.obs;
  bool _openingFullscreen = false; // 防止连点重复弹全屏

  /// 是否使用缩略图模式：网络视频 + 有缩略图 → 不预加载视频，点击才加载
  bool get _useThumb =>
      (widget.localPath == null || widget.localPath!.isEmpty) &&
      widget.thumbUrl != null &&
      widget.thumbUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_useThumb) {
      _initController();
    }
  }

  /// url/localPath/thumbUrl 变化时（如乐观渲染本地视频 -> 上传成功切换网络视频，
  /// 或列表复用 State 导致 widget 被替换），必须重建 controller，
  /// 否则会残留上一个视频的首帧/内容，出现多条视频显示相同的 bug。
  @override
  void didUpdateWidget(covariant VideoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.localPath != widget.localPath ||
        oldWidget.thumbUrl != widget.thumbUrl) {
      _resetController();
    }
  }

  Future<void> _resetController() {
    _controller?.dispose();
    _controller = null;
    _initialized.value = false;
    _loadFailed.value = false;
    if (_useThumb) {
      // 缩略图模式：无需初始化，等点击播放时懒加载
      return Future.value();
    }
    return _initController();
  }

  /// 创建并初始化视频控制器（成功返回 controller，失败返回 null，不触发 UI 状态）
  Future<VideoPlayerController?> _createController() async {
    try {
      final VideoPlayerController ctrl;
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        ctrl = VideoPlayerController.file(File(widget.localPath!));
      } else {
        ctrl = VideoPlayerController.networkUrl(
          Uri.parse(buildStaticUrl(widget.url)),
        );
      }
      await ctrl.initialize();
      return ctrl;
    } catch (e) {
      debugPrint('视频加载失败: $e');
      return null;
    }
  }

  Future<void> _initController() async {
    final ctrl = await _createController();
    if (!mounted) {
      ctrl?.dispose();
      return;
    }
    if (ctrl == null) {
      _loadFailed.value = true;
      return;
    }
    _controller = ctrl;
    _initialized.value = true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 点击进入全屏播放器
  /// - 立即弹全屏（不阻塞等待加载），加载转圈由全屏播放器内部显示；
  /// - 已初始化过 controller（旧逻辑/本地占位）时直接传入复用，不重复加载；
  /// - 缩略图模式 controller 为空，传 url/localPath 由全屏播放器自行加载。
  Future<void> _playFullscreen() async {
    if (_openingFullscreen) return;
    _openingFullscreen = true;
    try {
      if (!mounted) return;
      final VideoPlayerController? existing = _controller;
      showDialog(
        context: context,
        builder: (ctx) => _FullscreenVideoPlayer(
          controller: existing,
          url: widget.url,
          localPath: widget.localPath,
        ),
      );
    } finally {
      _openingFullscreen = false;
    }
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
        child: _useThumb
            // 缩略图模式：显示图片 + 播放按钮，点击立即进全屏加载
            ? GestureDetector(
                onTap: _playFullscreen,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      imageUrl: widget.thumbUrl!,
                      fit: BoxFit.cover,
                      type: AppImageType.general,
                    ),
                    // 中央播放按钮
                    Center(
                      child: Container(
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
                    ),
                  ],
                ),
              )
            : Obx(() => _loadFailed.value
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
                                  _formatDuration(_controller!
                                      .value.duration.inSeconds),
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

/// 全屏视频播放器（带控制条）
/// 两种入口：
/// - [controller] 非空：外部已初始化好的控制器，直接播放，不重复加载；
/// - [controller] 为空：根据 [url]/[localPath] 自行加载，加载中显示转圈，
///   加载完成自动播放，失败显示重试。
/// 控制条：底部播放/暂停 + 可拖动进度条 + 时间；顶部关闭按钮；点击画面切换显隐。
class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String? url;
  final String? localPath;

  const _FullscreenVideoPlayer({
    this.controller,
    this.url,
    this.localPath,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loadFailed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    if (c != null) {
      // 外部已初始化（旧逻辑/本地占位），直接播放
      _controller = c;
      c.setLooping(false);
      c.seekTo(Duration.zero);
      c.play();
    } else {
      _load();
    }
  }

  /// 全屏内加载视频（缩略图模式入口）
  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
    });
    try {
      final String? lp = widget.localPath;
      final VideoPlayerController ctrl = (lp != null && lp.isNotEmpty)
          ? VideoPlayerController.file(File(lp))
          : VideoPlayerController.networkUrl(
              Uri.parse(buildStaticUrl(widget.url!)),
            );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _controller = ctrl;
      setState(() {});
      ctrl.setLooping(false);
      ctrl.seekTo(Duration.zero);
      ctrl.play();
    } catch (e) {
      debugPrint('全屏视频加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    // 仅释放自己创建的 controller；外部传入的由气泡持有者释放
    if (widget.controller == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      // 加载中 / 加载失败
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: _loadFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white54, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      '视频加载失败',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('重试',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '视频加载中...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          // 视频画面
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          ),
          // 顶部关闭按钮
          if (_showControls)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () {
                  ctrl.pause();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          // 底部控制条
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControlBar(ctrl),
            ),
        ],
      ),
    );
  }

  Widget _buildControlBar(VideoPlayerController ctrl) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: ctrl,
        builder: (context, value, _) {
          return Row(
            children: [
              // 播放/暂停
              IconButton(
                onPressed: () {
                  if (value.isPlaying) {
                    ctrl.pause();
                  } else {
                    // 播放到末尾后再次播放：从头开始
                    if (value.position >= value.duration &&
                        value.duration > Duration.zero) {
                      ctrl.seekTo(Duration.zero);
                    }
                    ctrl.play();
                  }
                },
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              // 可拖动进度条
              Expanded(
                child: VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              // 时间显示
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Text(
                  '${_fmt(value.position)}/${_fmt(value.duration)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
