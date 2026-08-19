import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/pages/stranger_preview.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQr extends StatefulWidget {
  const ScanQr({super.key});

  @override
  State<ScanQr> createState() {
    return _ScanQrState();
  }
}

class _ScanQrState extends State<ScanQr> {
  late MobileScannerController _controller;
  late ThemeController _themeController;
  bool scanned = false;

  @override
  void initState() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, // 识别速度
      torchEnabled: false, // 默认关闭闪光灯
      facing: CameraFacing.back, // 默认后置摄像头
      returnImage: false, // 不返回每一帧图像 更省性能
    );
    _themeController = Get.find<ThemeController>();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    // 已识别过则直接 return
    if (scanned) return;

    // 取出第一个二维码
    final Barcode? barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final String content = barcode.rawValue!;

    // 判断是用户加好友二维码格式
    if (content.startsWith("uid:")) {
      scanned = true;
      String targetUid = content.replaceFirst("uid:", "");
      final OtherInfoState otherInfoState = await UserService.getOtherInfo(
        targetUid,
      );
      if (otherInfoState.isSuccess && mounted) {
        Get.off(StrangerPreview(targetUid: targetUid));
      } else if (!otherInfoState.isSuccess && mounted) {
        showTipSnackbar(msg: otherInfoState.msg, isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("扫一扫加好友"),backgroundColor: _themeController.currentTheme.secondColor,),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: onDetect),
          // 扫码框遮罩
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.flash_on,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
