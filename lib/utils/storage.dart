import 'dart:convert';

import 'package:chatapp/dto/dto_image.dart';
import 'package:chatapp/dto/dto_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveLoginData(LoginResp data) async {
  // 获取本地存储实例，单例对象
  // 本质：XML 文件，键值对持久化存储，应用卸载才会清空，清除缓存不会删、重启手机依然保留；
  // 权限：沙盒隔离，其他 App 无法读取，安全存放 token、uid、基础用户信息。
  await patchLoginStorage(
    token: data.token,
    uid: data.uid,
    nickname: data.nickname,
    avatar: data.avatar,
    bgImg: data.bgImg,
    intro: data.intro,
    birthday: data.birthday,
    gender: data.gender,
  );
}

// 只更新局部存储
Future<void> patchLoginStorage({
  String? token,
  String? uid,
  String? nickname,
  ImageResp? avatar,
  ImageResp? bgImg,
  String? intro,
  String? birthday,
  int? gender,
}) async {
  final sp = await SharedPreferences.getInstance();
  if (token != null) await sp.setString("token", token);
  if (uid != null) await sp.setString("uid", uid);
  if (nickname != null) await sp.setString("nickname", nickname);
  if (avatar != null) await sp.setString("avatar", jsonEncode(avatar.toJson()));
  if (bgImg != null) await sp.setString("bgImg", jsonEncode(bgImg.toJson()));
  if (intro != null) await sp.setString("intro", intro);
  if (birthday != null) await sp.setString("birthday", birthday);
  if (gender != null) await sp.setInt("gender", gender);
}

Future<LoginResp?> getLoginData() async {
  final sp = await SharedPreferences.getInstance();

  String? token = sp.getString("token");
  // 无登录数据直接返回null
  if(token == null || token.isEmpty) return null;

  // 读取json字符串，解码回map
  String avatarStr = sp.getString("avatar") ?? "{}";
  String bgImgStr = sp.getString("bgImg") ?? "{}";
  Map<String, dynamic> avatarMap = jsonDecode(avatarStr);
  Map<String, dynamic> bgImgMap = jsonDecode(bgImgStr);

  return LoginResp.fromJson({
    "token": token,
    "uid": sp.getString("uid"),
    "nickname": sp.getString("nickname"),
    "avatar": avatarMap,
    "bgImg": bgImgMap,
    "intro": sp.getString("intro"),
    "birthday": sp.getString("birthday"),
    "gender": sp.getInt("gender") ?? -1,
  });
}

Future<void> clearLoginData() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove("token");
  await sp.remove("uid");
  await sp.remove("nickname");
  await sp.remove("avatar");
  await sp.remove("bgImg");
  await sp.remove("intro");
  await sp.remove("birthday");
  await sp.remove("gender");
}
