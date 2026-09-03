import 'dart:convert';

/// 语音消息内容解析
/// 语音消息的 content 为 JSON 字符串：
/// {"url":"/static/chatVoice/20260903/xxx.m4a","duration":5.2}
/// duration 单位：秒
class VoiceMessageContent {
  final String url; // 语音文件 URL
  final double duration; // 时长（秒）

  const VoiceMessageContent({
    required this.url,
    this.duration = 0,
  });

  /// 从消息 content 解析，若解析失败返回 null（说明是文本消息）
  static VoiceMessageContent? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return null;
      final url = map['url'];
      if (url is! String || url.isEmpty) return null;
      return VoiceMessageContent(
        url: url,
        duration: (map['duration'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 生成语音消息的 content JSON 字符串
  static String build(String url, double duration) {
    return jsonEncode({
      'url': url,
      'duration': duration,
    });
  }

  /// 格式化时长显示：xx"
  String get durationText {
    final int sec = duration.round();
    return '$sec"';
  }
}
