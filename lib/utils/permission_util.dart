import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  /// 请求相册图片权限（仅Android）
  static Future<PermissionStatus> requestGallery() async {
    return await Permission.photos.request();
  }

  /// 校验相册权限，拒绝则跳转系统设置
  static Future<bool> checkGalleryPermission() async {
    PermissionStatus status = await requestGallery();
    // 永久拒绝，引导去设置
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return status.isGranted;
  }
}