import 'package:chatapp/dto/dto_image.dart';

class LoginResp {
  String token;
  String uid;
  String nickname;
  ImageResp avatar;
  ImageResp bgImg;
  String intro;
  String birthday;
  int gender;

  LoginResp({
    required this.token,
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.bgImg,
    required this.intro,
    required this.birthday,
    required this.gender,
  });


  LoginResp.fromJson(Map<String, dynamic> json)
    : token = json["token"] ?? "",
      uid = json["uid"] ?? "",
      nickname = json["nickname"] ?? "",
      avatar = ImageResp.fromJson(json["avatar"] ?? {}),
      bgImg = ImageResp.fromJson(json["bgImg"] ?? {}),
      intro = json["intro"] ?? "",
      birthday = json["birthday"] ?? "",
      gender = json["gender"] ?? -1;

  // Map<String, dynamic> toJson() {
  //   return {
  //     "token": token,
  //     "uid": uid,
  //     "nickname": nickname,
  //     "avatar": avatar.toJson(),
  //     "bgImg": bgImg.toJson(),
  //     "intro": intro,
  //     "birthday": birthday,
  //     "gender": gender,
  //   };
  // }
}
