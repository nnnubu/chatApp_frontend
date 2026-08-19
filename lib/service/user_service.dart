import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:chatapp/api/user_api.dart';
import 'package:chatapp/dto/dto_base.dart';
import 'package:chatapp/dto/dto_image.dart';
import 'package:chatapp/dto/dto_login.dart';
import 'package:chatapp/dto/dto_others.dart';

class CommonState {
  final bool isSuccess;
  final String msg;
  final dynamic data;
  CommonState({required this.isSuccess, required this.msg, this.data});
}

class LoginState extends CommonState {
  final LoginResp? loginResponse;
  LoginState({
    required super.isSuccess,
    required super.msg,
    this.loginResponse,
  });
}

class OtherInfoState extends CommonState {
  final OtherUsers? otherUserInfo;
  OtherInfoState({
    required super.isSuccess,
    required super.msg,
    this.otherUserInfo,
  });
}

class UploadState extends CommonState {
  final ImageResp? imageResp;
  UploadState({required super.isSuccess, required super.msg, this.imageResp});
}

class UserService {
  static Future<LoginState> login(String email, String password) async {
    try {
      final data = await UserApi.login(email, password);

      if (data == null) {
        return LoginState(isSuccess: false, msg: "登录数据获取失败，请重试");
      }
      final loginResponse = LoginResp.fromJson(data);
      if (loginResponse.token.isEmpty) {
        return LoginState(isSuccess: false, msg: "登录凭证获取失败，请重试");
      }

      return LoginState(
        isSuccess: true,
        msg: "登录成功",
        loginResponse: loginResponse,
      );
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return LoginState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> register(
    String nickname,
    String password,
    String email,
    String code,
  ) async {
    try {
      await UserApi.register(nickname, password, email, code);
      return CommonState(isSuccess: true, msg: "注册成功");
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> resetPwd(
    String email,
    String code,
    String password,
  ) async {
    try {
      await UserApi.resetPwd(email, code, password);
      return CommonState(isSuccess: true, msg: "重置密码成功");
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> sendCode(String email, String type) async {
    try {
      await UserApi.sendCode(email, type);
      return CommonState(isSuccess: true, msg: "验证码发送成功，5分钟内有效");
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<UploadState> uploadImage(Uint8List bytes, String type) async {
    try {
      final data = await UserApi.uploadImage(bytes, type);

      if (data == null) {
        return UploadState(isSuccess: false, msg: "图片数据获取失败，请重试");
      }
      final imageResp = ImageResp.fromJson(data);

      return UploadState(isSuccess: true, msg: "更新成功", imageResp: imageResp);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return UploadState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> updateInfo(Map<String, dynamic> body) async {
    try {
      await UserApi.updateInfo(body);
      return CommonState(isSuccess: true, msg: "更新成功");
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<UploadState> getUserQR() async {
    try {
      final data = await UserApi.getUserQR();
      if (data == null) {
        return UploadState(isSuccess: false, msg: "图片数据获取失败，请重试");
      }
      final imageResp = ImageResp.fromJson(data);
      return UploadState(isSuccess: true, msg: "获取二维码成功", imageResp: imageResp);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return UploadState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<OtherInfoState> getOtherInfo(String targetUid) async {
    try {
      final data = await UserApi.visitOthers(targetUid);
      if (data == null) {
        return OtherInfoState(isSuccess: false, msg: "访问失败，请重试");
      }
      final otherUserinfo = OtherUsers.fromJson(data);
      return OtherInfoState(
        isSuccess: true,
        msg: "访问成功",
        otherUserInfo: otherUserinfo,
      );
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return OtherInfoState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> addFriend(String targetUid, String msg) async {
    try {
      await UserApi.addFriend(targetUid, msg);
      return CommonState(isSuccess: true, msg: "已发送好友请求");
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> updateApply(String msgId, bool isAgree) async {
    try {
      String msg = isAgree ? "你们已经成为好友" : "已拒绝该好友申请";
      await UserApi.updateApply(msgId, isAgree);
      return CommonState(isSuccess: true, msg: msg);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> pullOfflineApply() async {
    try {
      final List<dynamic>? data = await UserApi.pullOfflineApply();
      return CommonState(isSuccess: true, msg: "", data: data);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> pullCategory() async {
    try {
      final List<dynamic>? data = await UserApi.pullCategory();
      return CommonState(isSuccess: true, msg: "", data: data);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> pullFriends(int page, int pageSize) async {
    try {
      final Map<String, dynamic>? data = await UserApi.pullFriends(
        page,
        pageSize,
      );
      return CommonState(isSuccess: true, msg: "", data: data);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }

  static Future<CommonState> pullMessage(
    int pageSize,
    String? cursorMsgId,
    String conversationUid,
  ) async {
    try {
      final Map<String, dynamic>? data = await UserApi.pullMessage(
        pageSize,
        cursorMsgId,
        conversationUid,
      );
      return CommonState(isSuccess: true, msg: "", data: data);
    } catch (e) {
      String errMsg = ErrorMsgConstant.networkDefaultErr;
      if (e is DioException) {
        errMsg = e.message ?? ErrorMsgConstant.networkDefaultErr;
      }
      return CommonState(isSuccess: false, msg: errMsg);
    }
  }
}
