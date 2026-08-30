import 'package:chatapp/dto/dto_image.dart';
import 'package:chatapp/widgets/app_image.dart';
import 'package:flutter/material.dart';

/// 用户头像组件
Widget userAvater({required ImageResp avatar}) {
  return AppImage(
    imageUrl: avatar.url,
    width: 120,
    height: 120,
    type: AppImageType.avatar,
    borderRadius: BorderRadius.circular(60),
  );
}

/// 用户背景图组件
Widget userBgImg({required ImageResp bgImg}) {
  return AppImage(
    imageUrl: bgImg.url,
    width: double.infinity,
    height: double.infinity,
    type: AppImageType.background,
    fit: BoxFit.cover,
  );
}
