import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:chatapp/dto/dto_base.dart';

class UserApi {
  // static 修饰证明这是 类 本身的方法  什么都不加就是指是 类实例 的方法

  // dio 已经 处理了 code 和 message ，此处的 res 只剩下 后端返回的 data 有的可能不返回 则为 null 返回的基本都是 Map
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    Response res = await DioUtil.dio.post(
      "api/login",
      data: {"email": email, "password": password},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> register(
    String nickname,
    String password,
    String email,
    String code,
  ) async {
    Response res = await DioUtil.dio.post(
      "api/register",
      data: {
        "nickname": nickname,
        "password": password,
        "email": email,
        "code": code,
      },
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> resetPwd(
    String email,
    String code,
    String password,
  ) async {
    Response res = await DioUtil.dio.post(
      "api/resetPwd",
      data: {"email": email, "code": code, "password": password},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> sendCode(
    String email,
    String type,
  ) async {
    Response res = await DioUtil.dio.post(
      "api/sendCode",
      data: {"email": email, "type": type},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> uploadImage(
    Uint8List bytes,
    String type,
  ) async {
    String fileName = "$type${DateTime.now().millisecondsSinceEpoch}.jpg";
    MultipartFile file = MultipartFile.fromBytes(
      bytes,
      filename: fileName,
      contentType: DioMediaType.parse("image/jpeg"),
    );
    FormData formData = FormData.fromMap({"file": file, "uploadType": type});
    Response res = await DioUtil.dio.post(
      "auth/uploadImage",
      data: formData,
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateInfo(
    Map<String, dynamic> body,
  ) async {
    Response res = await DioUtil.dio.post(
      "auth/updateInfo",
      data: body,
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getUserQR() async {
    Response res = await DioUtil.dio.post("auth/getUserQR");
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> visitOthers(String targetUid) async {
    Response res = await DioUtil.dio.post(
      "auth/visitOthers",
      data: {"targetUid": targetUid},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> addFriend(
    String targetUid,
    String msg,
  ) async {
    Response res = await DioUtil.dio.post(
      "auth/addFriend",
      data: {"targetUid": targetUid, "msg": msg},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateApply(
    String msgId,
    bool isAgree,
  ) async {
    Response res = await DioUtil.dio.post(
      "auth/updateApply",
      data: {"msgId": msgId, "isAgree": isAgree},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<List<dynamic>?> pullOfflineApply() async {
    Response res = await DioUtil.dio.get("auth/pullOfflineApply");
    return res.data as List<dynamic>?;
  }

  static Future<List<dynamic>?> pullCategory() async {
    Response res = await DioUtil.dio.get("auth/pullCategory");
    return res.data as List<dynamic>?;
  }

  static Future<Map<String, dynamic>?> pullFriends(
    int page,
    int pageSize,
  ) async {
    Response res = await DioUtil.dio.get(
      "auth/pullFriends",
      queryParameters: {"page": page, "pageSize": pageSize},
    );
    return res.data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> pullMessage(
    int pageSize,
    String? cursorMsgId,
    String conversationUid,
  ) async {
    Response res = await DioUtil.dio.get(
      "auth/pullMessages",
      queryParameters: cursorMsgId == null
          ? {"pageSize": pageSize, "conversationUid": conversationUid}
          : {
              "pageSize": pageSize,
              "cursorMsgId": cursorMsgId,
              "conversationUid": conversationUid,
            },
    );
    return res.data as Map<String, dynamic>?;
  }
}
