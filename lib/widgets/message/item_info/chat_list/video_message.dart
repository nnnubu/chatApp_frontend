import 'dart:convert';

/// 视频消息内容解析
/// 视频消息的 content 为 JSON 字符串：
/// {"url":"/static/chatVideo/20260906/xxx.mp4"}
class VideoMessageContent {
  final String url; // 视频文件 URL

  const VideoMessageContent({required this.url});

  /// 从消息 content 解析，若解析失败返回 null（说明是文本消息）
  static VideoMessageContent? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return null;
      final url = map['url'];
      if (url is! String || url.isEmpty) return null;
      return VideoMessageContent(url: url);
    } catch (_) {
      return null;
    }
  }

  /// 生成视频消息的 content JSON 字符串
  static String build(String url) {
    return jsonEncode({'url': url});
  }
}
