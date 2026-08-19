import 'package:chatapp/dto/dto_image.dart';

class OtherUsers {
  String uid;
  String nickname;
  String intro;
  ImageResp avatar;
  ImageResp bgImg;
  bool isFriend;
  String? conversationUid;

  OtherUsers({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.bgImg,
    required this.intro,
    required this.isFriend,
    this.conversationUid,
  });

  OtherUsers.fromJson(Map<String, dynamic> json)
    : uid = json["uid"] ?? "",
      nickname = json["nickname"] ?? "",
      intro = json["intro"] ?? "",
      avatar = ImageResp.fromJson(json["avatar"] ?? {}),
      bgImg = ImageResp.fromJson(json["bgImg"] ?? {}),
      isFriend = json["isFriend"] ?? false,
      conversationUid = json["conversationUid"];

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "nickname": nickname,
      "Intro": intro,
      "avatar": avatar.toJson(),
      "bgImg": bgImg.toJson(),
      "isFriend": isFriend,
      "conversationUid":conversationUid,
    };
  }
}
