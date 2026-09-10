import 'dart:convert';

/// 表情包消息内容
/// content JSON: {"url": "/static/userSticker/xxx.png", "stickerId": "xxx"}
class StickerMessageContent {
  final String url;
  final String? stickerId;

  StickerMessageContent({required this.url, this.stickerId});

  static StickerMessageContent? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final map = jsonDecode(content) as Map<String, dynamic>;
      final url = map['url'] as String?;
      if (url == null || url.isEmpty) return null;
      return StickerMessageContent(
        url: url,
        stickerId: map['stickerId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String toJson() => jsonEncode({
        'url': url,
        if (stickerId != null) 'stickerId': stickerId,
      });
}
