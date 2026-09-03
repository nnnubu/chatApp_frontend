import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 全局语音播放器单例
/// 所有语音气泡共享同一个 AudioPlayer，同一时刻只播放一条语音。
/// 插件不可用（MissingPluginException）时优雅降级，不阻塞 UI。
class VoicePlayerManager {
  VoicePlayerManager._();

  static final VoicePlayerManager instance = VoicePlayerManager._();

  late final AudioPlayer _player;
  bool _initTried = false;
  bool _available = true;
  String? currentUrl;
  double currentDuration = 0;
  bool isPlaying = false;
  final ValueNotifier<int> version = ValueNotifier(0);
  Timer? _completeGuard;

  bool get available => _available;

  /// 初始化：创建播放器 + 配置 Android 音频上下文 + 事件监听
  void _ensureInit() {
    if (_initTried) return;
    _initTried = true;
    try {
      _player = AudioPlayer()
        // Android 播放配置：媒体音量、音乐类型、自动获得音频焦点
        ..setAudioContext(AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ))
        // stop 模式：播完即停止并触发 onPlayerComplete
        ..setReleaseMode(ReleaseMode.stop);

      _player.onPlayerStateChanged.listen((state) {
        isPlaying = state == PlayerState.playing;
        version.value++;
        // 离开播放状态时清理兜底定时器
        if (!isPlaying) {
          _completeGuard?.cancel();
          _completeGuard = null;
        }
      });
      _player.onPlayerComplete.listen((_) {
        _finishPlayback();
      });
    } catch (e) {
      debugPrint('语音播放器初始化失败(插件不可用): $e');
      _available = false;
    }
  }

  void _finishPlayback() {
    _completeGuard?.cancel();
    _completeGuard = null;
    isPlaying = false;
    currentUrl = null;
    version.value++;
  }

  /// 播放/暂停。url 相同则暂停/恢复，url 不同则切换播放
  /// [localPath] 非空时播放本地文件（乐观渲染/上传失败阶段），否则播放网络 URL
  Future<void> toggle(String url, double duration, {String? localPath}) async {
    _ensureInit();
    if (!_available) return;
    try {
      if (currentUrl == url && isPlaying) {
        await _player.pause();
      } else if (currentUrl == url) {
        await _player.resume();
        _scheduleCompleteGuard(duration);
      } else {
        currentUrl = url;
        currentDuration = duration;
        await _player.stop();
        if (localPath != null && localPath.isNotEmpty) {
          // 本地文件播放（乐观渲染/上传失败时）
          await _player.play(DeviceFileSource(localPath));
        } else {
          await _player.play(UrlSource(buildStaticUrl(url)));
        }
        isPlaying = true;
        version.value++;
        _scheduleCompleteGuard(duration);
      }
    } catch (e) {
      debugPrint('语音播放失败: $e');
      _available = false;
    }
  }

  /// 兜底：如果超过（时长 + 缓冲余量）仍未收到 onPlayerComplete，强制还原状态
  void _scheduleCompleteGuard(double duration) {
    _completeGuard?.cancel();
    final timeout = (duration.clamp(1, 60) + 3).toInt();
    _completeGuard = Timer(Duration(seconds: timeout), () {
      if (isPlaying && currentUrl != null) {
        debugPrint('语音播放超时兜底，强制还原状态');
        _finishPlayback();
      }
    });
  }

  /// 停止播放（页面退出时调用）
  void stop() {
    _completeGuard?.cancel();
    _completeGuard = null;
    if (_initTried && _available) {
      try {
        _player.stop();
      } catch (_) {}
    }
    isPlaying = false;
    currentUrl = null;
    version.value++;
  }
}

/// 语音消息气泡
/// 显示播放/停止按钮 + 时长 + 音波，点击播放/暂停。
/// 通过全局 VoicePlayerManager 共享播放器，避免每个气泡独立创建导致插件异常。
class VoiceBubble extends StatefulWidget {
  final String url; // 语音相对路径（网络 URL 或本地文件路径）
  final double duration; // 时长（秒）
  final bool isSelf; // 是否自己发的（控制颜色）
  final String? localPath; // 本地文件路径：乐观渲染/上传失败阶段播放本地录音

  const VoiceBubble({
    super.key,
    required this.url,
    required this.duration,
    required this.isSelf,
    this.localPath,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  ThemeController? _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = _themeController!.currentTheme;
    final String durationText = '${widget.duration.round()}"';
    // 气泡宽度随时长变化（微信风格：越长越宽）
    final double bubbleWidth =
        (70 + widget.duration.clamp(1, 60) * 1.6).clamp(104.0, 200.0);

    return GestureDetector(
      onTap: () => VoicePlayerManager.instance
          .toggle(widget.url, widget.duration, localPath: widget.localPath),
      child: Container(
        width: bubbleWidth,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelf ? t.primaryColor : t.secondColor,
          borderRadius: BorderRadius.circular(20),
        ),
        // 用 ValueListenableBuilder 监听全局播放状态，当前气泡播放时高亮
        child: ValueListenableBuilder<int>(
          valueListenable: VoicePlayerManager.instance.version,
          builder: (context, _, __) {
            final bool playingHere = VoicePlayerManager.instance.isPlaying &&
                VoicePlayerManager.instance.currentUrl == widget.url;
            return Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  playingHere ? Icons.stop : Icons.play_arrow,
                  size: 20,
                  color: widget.isSelf ? Colors.white : t.fontColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: playingHere
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            durationText,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isSelf ? Colors.white : t.fontColor,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            return Container(
                              width: 3,
                              height: 5 + (i * 3).toDouble(),
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(
                                color: widget.isSelf
                                    ? Colors.white.withOpacity(0.9)
                                    : t.fontColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                ),
                Text(
                  durationText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelf ? Colors.white : t.fontColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
