import 'package:chatapp/api/config.dart';

String buildStaticUrl(String relativePath) {
  if (relativePath.isEmpty) return "";
  String server = ApiConfig.baseUrl;
  // 处理路径重复斜杠
  if (relativePath.startsWith("/")) {
    return "$server$relativePath";
  } else {
    return "$server/$relativePath";
  }
}