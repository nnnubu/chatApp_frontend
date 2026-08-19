import 'package:chatapp/dto/dto_image.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:flutter/material.dart';

Widget userAvater({required ImageResp avatar}) {
  if (avatar.url.isEmpty) {
    return Container(color: Colors.grey); // 占位，不渲染空url的Image.network
  }
  return Container(
    height: 120,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
    child: Image.network(
      buildStaticUrl(avatar.url),
      cacheHeight: avatar.thumbH,
      cacheWidth: avatar.thumbW,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        return Container(
          decoration: BoxDecoration(color: Colors.grey),
          child: Icon(Icons.error),
        );
      },
    ),
  );
}

Widget userBgImg({required ImageResp bgImg}) {
  if (bgImg.url.isEmpty) {
    return Container(color: Colors.grey); // 占位，不渲染空url的Image.network
  }
  return Container(
    decoration: BoxDecoration(color: Colors.black54),
    child: Image.network(
      buildStaticUrl(bgImg.url),
      cacheHeight: bgImg.thumbH,
      cacheWidth: bgImg.thumbW,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        return Container(
          decoration: BoxDecoration(color: Colors.grey),
          child: Icon(Icons.error),
        );
      },
    ),
  );
}
