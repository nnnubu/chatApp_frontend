import 'dart:convert';

/// 图片消息内容解析
/// 图片消息的 content 为 JSON 字符串：
/// {"url":"/static/chatImg/origin/xxx.jpg","thumb":"/static/chatImg/thumb/xxx.jpg","width":800,"height":600}
/// 文本消息 content 为纯字符串
class ImageMessageContent {
  final String url; // 原图 URL
  final String thumb; // 缩略图 URL
  final int width; // 原图宽度
  final int height; // 原图高度

  const ImageMessageContent({
    required this.url,
    required this.thumb,
    this.width = 0,
    this.height = 0,
  });

  /// 从消息 content 解析，若解析失败返回 null（说明是文本消息）
  /// 注意：必须存在 width/height 或 thumb 才算图片消息，
  /// 避免语音消息（{"url","duration"}）因同样有 url 字段而被误判为图片
  static ImageMessageContent? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final map = jsonDecode(content);
      if (map is! Map<String, dynamic>) return null;
      final url = map['url'];
      if (url is! String || url.isEmpty) return null;
      final width = (map['width'] as num?)?.toInt() ?? 0;
      final height = (map['height'] as num?)?.toInt() ?? 0;
      final thumb = map['thumb'];
      // 图片消息必须带有尺寸或缩略图字段；只有 url（如语音）不算图片
      if (width <= 0 || height <= 0) {
        if (thumb is! String || thumb.isEmpty) return null;
      }
      return ImageMessageContent(
        url: url,
        thumb: (map['thumb'] as String?) ?? url,
        width: width,
        height: height,
      );
    } catch (_) {
      return null;
    }
  }

  /// 生成图片消息的 content JSON 字符串
  static String build(String originUrl, String thumbUrl, int width, int height) {
    return jsonEncode({
      'url': originUrl,
      'thumb': thumbUrl,
      'width': width,
      'height': height,
    });
  }
}
