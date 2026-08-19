import 'dart:async';

import 'package:chatapp/dto/dto_login.dart';
import 'package:chatapp/utils/storage.dart';
import 'package:chatapp/dto/dto_image.dart';
import 'package:get/get.dart';

// GetxController 是它提供的全局状态控制器基类，专门用来
// 全局单例管理内存数据（全 App 共享一份实例）
// 内置响应式变量（Rx 类型），数据变了 UI 自动刷新
// 自带生命周期（onInit/onClose），页面销毁自动释放资源 但是要写在页面的 build 内部与页面的生命周期绑定才行 但是可以用 permanent: true 来让该控制器强制常驻 另外自动销毁仅仅支持 GetX 自带 的路由跳转 Get.to() / Get.off() / Get.back() 使用原生的 Navigator.push / Navigator.pop 就不行，使用原生的页面跳转，就需要进行手动删除控制器 如 Get.delete<UserController>()

class UserController extends GetxController {
  final Rx<LoginResp?> _userInfo = Rx(null);

  // 取值代理
  Rx<LoginResp?> get userInfo => _userInfo;
  int get gender => _userInfo.value?.gender ?? 0;
  String get token => _userInfo.value?.token ?? "";
  String get uid => _userInfo.value?.uid ?? "";
  String get nickname => _userInfo.value?.nickname ?? "";
  String get intro => _userInfo.value?.intro ?? "";
  String get birthday => _userInfo.value?.birthday ?? "";
  ImageResp get avatar =>
      _userInfo.value?.avatar ?? ImageResp(url: "", thumbW: 0, thumbH: 0);
  ImageResp get bgImg =>
      _userInfo.value?.bgImg ?? ImageResp(url: "", thumbW: 0, thumbH: 0);
  bool get isLogin => _userInfo.value != null && token.isNotEmpty;

  void setUserInfo(LoginResp resp) {
    userInfo.value = resp;
  }

  void patchUserInfo({
    String? token,
    String? uid,
    String? nickname,
    ImageResp? avatar,
    ImageResp? bgImg,
    String? intro,
    String? birthday,
    int? gender,
  }) {
    final old = userInfo.value;
    if (old == null) return;
    // Rx 会对比新旧 value 的引用地址，地址发生变化则会自动让 Obx 重建 UI
    // 或者 使用 update 手动重建 GetBuilder 内的 UI

    // 这里如果直接使用 userInfo.value!.token = newToken 这种改变value 内部字段 的形式， 由于 value 的地址还是旧的 所以不会更新
    // 但其实使用 update 还是会强制更新的 但是有的 value 的内部字段是 final 不支持 二次赋值
    // 因此 要重新构造一个新的 value 实例才可更新，后面的清除函数同理

    userInfo.value = LoginResp(
      token: token ?? old.token,
      uid: uid ?? old.uid,
      nickname: nickname ?? old.nickname,
      avatar: avatar ?? old.avatar,
      bgImg: bgImg ?? old.bgImg,
      intro: intro ?? old.intro,
      birthday: birthday ?? old.birthday,
      gender: gender ?? old.gender,
    );

    // 同步更新持久存储
    unawaited(
      patchLoginStorage(
        token: token,
        uid: uid,
        nickname: nickname,
        avatar: avatar,
        bgImg: bgImg,
        intro: intro,
        birthday: birthday,
        gender: gender,
      ),
    );
  }

  Future<void> clearUserInfo() async {
    userInfo.value = null;
    await clearLoginData();
  }

  Future<void> loadFromStorage() async {
    // 从磁盘读取信息并保存到响应变量
    LoginResp? data = await getLoginData();
    if (data != null) {
      setUserInfo(data);
    } else {
      clearUserInfo();
    }
  }
}
