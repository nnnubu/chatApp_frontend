import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showTipSnackbar({
  required String msg,
  bool isSuccess = true,
}) {
  Get.showSnackbar(
    GetSnackBar(
      // titleText: Text(
      //   isSuccess ? "操作成功" : "操作失败",
      //   style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      // ),
      messageText: Text(
        msg,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error_outline,
        color: Colors.white,
        size: 22,
      ),
      backgroundColor: isSuccess ? const Color(0xff43a047) : const Color(0xffe53935),
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(14),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      maxWidth: 360,
      boxShadows: [
        BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))
      ],
    ),
  );
}