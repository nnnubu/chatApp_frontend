class ImageResp {
  final String url;
  final int thumbW;
  final int thumbH;

  ImageResp({required this.url, required this.thumbW, required this.thumbH});

  factory ImageResp.fromJson(Map<String, dynamic> json) {
    return ImageResp(
      url: json["url"] ?? "",
      thumbW: json["thumbW"] ?? 0,
      thumbH: json["thumbH"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {"url": url, "thumbW": thumbW, "thumbH": thumbH};
  }
}
