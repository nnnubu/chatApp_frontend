import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CostomCropPage extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio; // 正方形 1 ，矩形 16/9
  final bool useCircleUi; // 圆形 Ui 开启与否
  final String filePrefix;
  final String pageTitle;
  const CostomCropPage({
    super.key,
    // imagePath 为从相册选中的图片本地绝对路径，用来渲染图片到裁剪画布
    required this.imageBytes,
    required this.aspectRatio,
    required this.useCircleUi,
    required this.filePrefix,
    required this.pageTitle,
  });

  @override
  State<CostomCropPage> createState() => _CostomCropPageState();
}

class _CostomCropPageState extends State<CostomCropPage> {
  // 裁剪组件控制器 _cropController 唯一的作用是主动触发裁剪
  final CropController _cropController = CropController();
  late final Uint8List _sourceImageBytes;
  late final ThemeController _themeController;
  final RxBool _loading = false.obs;

  // 点击确认按钮：仅触发裁剪指令，结果在 onCropped 回调接收
  Future<void> handleCrop() async {
    _loading.value = true;
    // 下发裁剪指令，异步进行图片裁剪运算
    // 该方法不会直接返回裁剪结果，而是通过 Crop 组件的 onCropped 回调推送
    _cropController.crop();
  }

  // 裁剪完成回调：拿到像素二进制数据、存本地、回传上一页
  Future<void> onCropFinish(CropResult result) async {
    // CropSuccess：裁剪成功，携带 croppedImage: Uint8List 图片二进制
    // CropFailure：裁剪失败（图片损坏、内存不足、权限异常），携带错误原因 cause

    switch (result) {
      case CropSuccess(croppedImage: final cropBytes):
        _loading.value = false;

        Get.back(result: cropBytes); // 关闭当前裁剪页并把二进制数据返回给上一页
        break;
      case CropFailure(cause: final err):
        _loading.value = false;

        showTipSnackbar(msg: "裁剪出错：${err.toString()}", isSuccess: false);
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _sourceImageBytes = widget.imageBytes;
    _themeController = Get.find<ThemeController>();
    // 初始化时读取图片 避免build阶段同步阻塞
  }

  @override
  void dispose() {
    // 全局清空图片缓存
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        backgroundColor: _themeController.currentTheme.secondColor,
        actions: [
          Obx(() {
            return _loading.value
                ? CircularProgressIndicator(color: _themeController.currentTheme.secondColor)
                : IconButton(
                    onPressed: handleCrop,
                    icon: const Icon(Icons.check),
                  );
          }),
        ],
      ),
      body: Crop(
        controller: _cropController,
        image: _sourceImageBytes,
        aspectRatio: widget.aspectRatio,
        baseColor: _themeController.currentTheme.backGroundColor,
        maskColor: Colors.black54,
        withCircleUi: widget.useCircleUi,

        interactive: false, // 开启手势交互，用户可拖动和放大缩小图片 但是这样就不能拖动裁剪区域了
        onCropped: onCropFinish, // 接收裁剪输出结果回调存储
        filterQuality: FilterQuality.low,
        // 自定义裁剪区域在画布中的初始大小
        initialRectBuilder: InitialRectBuilder.withBuilder((
          Rect viewportRect,
          Rect imageRect,
        ) {
          // 取画布最短边
          final shortSide = viewportRect.shortestSide;
          // 缩小到画布70%尺寸
          final targetSizeRate = 0.7;
          final targetWidth = shortSide * targetSizeRate;
          final targetHeight = targetWidth / widget.aspectRatio;
          return Rect.fromCenter(
            center: viewportRect.center,
            width: targetWidth,
            height: targetHeight,
          );
        }),

        // 自定义裁剪区域边框
        cornerDotBuilder: (double dotSize, EdgeAlignment edgeAlignment) {
          final size = dotSize * 0.8;
          return SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white60,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
        // 自定义裁剪区域样式
        overlayBuilder: (context, rect) {
          return SizedBox.fromSize(
            size: rect.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: widget.useCircleUi
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                border: Border.all(color: Colors.white30, width: 2.2),
              ),
            ),
          );
        },
      ),
    );
  }
}
