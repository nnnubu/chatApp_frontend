import 'dart:convert';

/// 视频消息内容解析
/// 视频消息的 content 为 JSON 字符串：
/// {"url":"/static/chatVideo/20260906/xxx.mp4","thumbUrl":"/static/chatVideo/20260906/xxx_thumb.jpg"}
/// thumbUrl 为视频缩略图（后端 ffmpeg 抽帧），旧消息可能没有该字段，前端回退直接用视频首帧。
class VideoMessageContent {
  final String url; // 视频文件 URL
  final String? thumbUrl; // 视频缩略图 URL（可能为空，旧消息兼容）

  const VideoMessageContent({required this.url, this.thumbUrl});

  /// 从消息 content 解析，若解析失败返回 null（说明不是视频消息）
  static VideoMessageContent? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return null;
      final url = map['url'];
      if (url is! String || url.isEmpty) return null;
      final thumb = map['thumbUrl'];
      return VideoMessageContent(
        url: url,
        thumbUrl: (thumb is String && thumb.isNotEmpty) ? thumb : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// 生成视频消息的 content JSON 字符串
  static String build(String url, {String? thumbUrl}) {
    return jsonEncode({
      'url': url,
      if (thumbUrl != null && thumbUrl.isNotEmpty) 'thumbUrl': thumbUrl,
    });
  }
}
