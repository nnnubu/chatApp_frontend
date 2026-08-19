import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Uint8List?> compressImage(String filePath) async {
  // 压缩图片尺寸 长边限制1080，质量85，平衡清晰度和体积
  final result = await FlutterImageCompress.compressWithFile(
    filePath,
    minWidth: 1080,
    minHeight: 1080,
    quality: 85,
    format: CompressFormat.jpeg,
  );
  return result;
}