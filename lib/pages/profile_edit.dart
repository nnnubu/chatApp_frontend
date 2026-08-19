import 'dart:typed_data';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/pages/custom_crop.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/utils/check_input.dart';
import 'package:chatapp/utils/compress_image.dart';
import 'package:chatapp/utils/permission_util.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/birthday_selector.dart';
import 'package:chatapp/widgets/gender_selector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

final double _bgImgHeight = AppBase.bgImgHeight - 150;

const Color shaderOpaqueWhite = Colors.white;
const Color shaderTransparent = Color(0x00FFFFFF);
const Alignment shaderBegin = Alignment.topCenter;
const Alignment shaderEnd = Alignment.bottomCenter;
final Gradient _bgImgGradient = LinearGradient(
  begin: shaderBegin,
  end: shaderEnd,
  colors: [shaderOpaqueWhite, shaderTransparent],
  stops: const [0.6, 1],
);

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ProfileEditState();
  }
}

class _ProfileEditState extends State<ProfileEdit>
    with SingleTickerProviderStateMixin {
  late int originGender;
  late String originBirth;
  late String originNick;
  late String originIntro;
  late final ThemeController _themeController;
  late final UserController _userController;
  late final TextEditingController _nickCtrl;
  late final TextEditingController _introCtrl;
  late final TextEditingController _genderCtrl;
  late final TextEditingController _birthCtrl;
  final UserController userCtrl = Get.find<UserController>();
  final Map<int, String> genderMap = {0: "保密", 1: "女", 2: "男"};
  final RxnString _nickError = RxnString();
  final RxnString _introError = RxnString();
  final RxBool _isSubmitting = false.obs;
  final RxBool _genderPopVisible = false.obs;
  final RxBool _birthPopVisible = false.obs;
  late int _selectGender;
  late String _selectBirth;

  Future<void> updateImage({required String uploadType}) async {
    late final bool useCircleUi;
    late final String pageTitle;
    late final double aspectRatio;

    if (uploadType == "avatar") {
      useCircleUi = true;
      pageTitle = "裁剪头像";
      aspectRatio = 1 / 1;
    } else if (uploadType == "bgImg") {
      useCircleUi = false;
      pageTitle = "裁剪背景图";
      aspectRatio = 16 / 9;
    }

    // 获取权限
    bool hasPermission = await PermissionUtil.checkGalleryPermission();
    if (!hasPermission) return;

    // 从相册挑选图片
    final XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;
    Uint8List? smallBytes = await compressImage(pickedFile.path);
    if (smallBytes == null) return;

    // 裁剪页面，等待裁剪完成回传本地路径
    final Uint8List? cropBytes = await Get.to(
      () => CostomCropPage(
        imageBytes: smallBytes,
        aspectRatio: aspectRatio,
        useCircleUi: useCircleUi,
        filePrefix: uploadType,
        pageTitle: pageTitle,
      ),
    );

    // 用户点返回取消裁剪，直接结束流程
    if (cropBytes == null) return;

    final UploadState uploadState = await UserService.uploadImage(
      cropBytes,
      uploadType,
    );

    if (uploadType == "avatar") {
      userCtrl.patchUserInfo(avatar: uploadState.imageResp);
    } else if (uploadType == "bgImg") {
      userCtrl.patchUserInfo(bgImg: uploadState.imageResp);
    }

    showTipSnackbar(msg: uploadState.msg, isSuccess: uploadState.isSuccess);
  }

  Future<void> updateInfo() async {
    if (_isSubmitting.value) return;

    _isSubmitting.value = true;

    Map<String, dynamic> reqBody = {};

    String nickname = _nickCtrl.text.trim();
    if (nickname != originNick) reqBody["nickname"] = nickname;

    String intro = _introCtrl.text.trim();
    if (intro != originIntro) reqBody["intro"] = intro;

    if (_selectGender != originGender) reqBody["gender"] = _selectGender;

    if (_selectBirth != originBirth) reqBody["birthday"] = _selectBirth;

    String? genderErr = CheckInput.gender(_selectGender);
    if (genderErr != null) {
      showTipSnackbar(msg: genderErr, isSuccess: false);
      _isSubmitting.value = false;
      return;
    }

    String? birthErr = CheckInput.birthday(_selectBirth);
    if (birthErr != null) {
      showTipSnackbar(msg: birthErr, isSuccess: false);
      _isSubmitting.value = false;
      return;
    }

    if (reqBody.isEmpty) {
      showTipSnackbar(msg: "您未修改任何资料", isSuccess: false);
      _isSubmitting.value = false;
      return;
    }

    final CommonState commonState = await UserService.updateInfo(reqBody);

    if (mounted) {
      _isSubmitting.value = false;
    }

    if (commonState.isSuccess) {
      userCtrl.patchUserInfo(
        nickname: nickname,
        intro: intro,
        gender: _selectGender,
        birthday: _selectBirth,
      );
      Get.back();
    }

    showTipSnackbar(msg: commonState.msg, isSuccess: commonState.isSuccess);
  }

  @override
  void initState() {
    super.initState();
    originGender = userCtrl.gender;
    originBirth = userCtrl.birthday;
    originNick = userCtrl.nickname;
    originIntro = userCtrl.intro;

    _selectGender = originGender;
    _selectBirth = originBirth;

    _themeController = Get.find<ThemeController>();
    _userController = Get.find<UserController>();

    _nickCtrl = TextEditingController(text: originNick);
    _introCtrl = TextEditingController(text: originIntro);
    _genderCtrl = TextEditingController(text: genderMap[originGender] ?? "保密");
    _birthCtrl = TextEditingController(text: originBirth);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _introCtrl.dispose();
    _genderCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double safeTop = DeviceSize.instance.statusBarHeight;
    AppTheme t = _themeController.currentTheme;
    return Scaffold(
      backgroundColor: t.backGroundColor,
      resizeToAvoidBottomInset: true,
      // SingleChildScrollView 单组件纵向滚动容器
      // 当内部子组件总高度 > 屏幕可视高度时，允许用户上下滑动查看全部内容 例如 键盘弹出的情况
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: _bgImgHeight,
                  width: double.infinity,
                  child: Stack(
                    alignment: AlignmentGeometry.center,
                    children: [
                      Positioned.fill(
                        child: Hero(
                          tag: "bgImg",
                          // 自定义跨页面共享元素飞行过渡的中间动画画面
                          flightShuttleBuilder:
                              (
                                BuildContext flightContext, // 动画独立上下文
                                Animation<double>
                                animation, // 动画进度 0 ~ 1，全程永远从0走到1
                                HeroFlightDirection
                                flightDirection, // 区分前进/返回两种飞行方向
                                BuildContext
                                fromHeroContext, // 来源页面Hero的组件上下文（上一页）
                                BuildContext
                                toHeroContext, // 目标页面Hero的组件上下文（下一页）
                              ) {
                                // 自定义过渡动画组件，该组件在动画结束之后会自动销毁
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    double currentStop;
                                    if (flightDirection ==
                                        HeroFlightDirection.push) {
                                      // 前进：涨潮 stop 1.0 → 0.6
                                      currentStop =
                                          1.0 - (animation.value * (1.0 - 0.6));
                                    } else {
                                      // 返回：退潮 stop 0.6 → 1.0
                                      currentStop =
                                          0.6 +
                                          (1 - animation.value) * (1.0 - 0.6);
                                    }
                                    // ShaderMask : 蒙版容器组件，可以直接修改子组件自身的像素透明度

                                    return ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          begin: shaderBegin,
                                          end: shaderEnd,
                                          colors: const [
                                            shaderOpaqueWhite,
                                            shaderTransparent,
                                          ],
                                          stops: [
                                            currentStop,
                                            1.0,
                                          ], // 动态随动画改变淡化起点
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                        ),
                                        child: Obx(() {
                                          return Image.network(
                                            buildStaticUrl(
                                              _userController.bgImg.url,
                                            ),
                                            cacheHeight:
                                                _userController.bgImg.thumbH,
                                            cacheWidth:
                                                _userController.bgImg.thumbW,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey,
                                                    ),
                                                    child: Icon(Icons.error),
                                                  );
                                                },
                                          );
                                        }),
                                      ),
                                    );
                                  },
                                );
                              },
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              // Rect 对象 代表当前 child 组件的矩形尺寸、坐标范围（宽高、上下左右边界）
                              // createShader 创建并返回 Shader 着色器
                              return _bgImgGradient.createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black54),
                              child: Obx(() {
                                return Image.network(
                                  buildStaticUrl(_userController.bgImg.url),
                                  cacheHeight: _userController.bgImg.thumbH,
                                  cacheWidth: _userController.bgImg.thumbW,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                      ),
                                      child: Icon(Icons.error),
                                    );
                                  },
                                );
                              }),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        child: Stack(
                          children: [
                            Hero(
                              tag: "avatar",
                              child: Container(
                                height: _bgImgHeight / 2,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                ),
                                child: Obx(() {
                                  return Image.network(
                                    buildStaticUrl(_userController.avatar.url),
                                    cacheHeight: _userController.avatar.thumbH,
                                    cacheWidth: _userController.avatar.thumbW,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                        ),
                                        child: Icon(Icons.error),
                                      );
                                    },
                                  );
                                }),
                              ),
                            ),

                            Positioned.fill(
                              child: Container(
                                height: _bgImgHeight / 2,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: TextButton(
                                  onPressed: () =>
                                      updateImage(uploadType: "avatar"),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 35,
                                      ),
                                      Text(
                                        "更换头像",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Obx(() {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          obscureText: false,
                          controller: _nickCtrl,
                          decoration: InputDecoration(
                            labelText: "昵称",
                            hintText: "请输入昵称",
                            errorText: _nickError.value,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            _nickError.value = CheckInput.nickname(
                              value.trim(),
                            );
                          },
                        ),

                        SizedBox(height: 12),

                        TextFormField(
                          obscureText: false,
                          controller: _introCtrl,
                          decoration: InputDecoration(
                            labelText: "简介",
                            hintText: "请输入简介",
                            errorText: _introError.value,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            _introError.value = CheckInput.intro(value);
                          },
                        ),

                        SizedBox(height: 12),

                        TextFormField(
                          obscureText: false,
                          readOnly: true,
                          controller: _genderCtrl,
                          decoration: InputDecoration(
                            labelText: "性别",
                            hintText: "请选择性别",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onTap: () {
                            _genderPopVisible.value = true;
                          },
                        ),

                        SizedBox(height: 12),

                        TextFormField(
                          obscureText: false,
                          readOnly: true,
                          controller: _birthCtrl,
                          decoration: InputDecoration(
                            labelText: "生日",
                            hintText: "请选择",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onTap: () {
                            _birthPopVisible.value = true;
                          },
                        ),

                        SizedBox(height: 12),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: t.secondColor,
                          ),
                          onPressed: () {
                            // 恢复选择变量
                            _selectGender = originGender;
                            _selectBirth = originBirth;
                            // 恢复输入框文字
                            _nickCtrl.text = originNick;
                            _introCtrl.text = originIntro;
                            _genderCtrl.text = genderMap[originGender]!;
                            _birthCtrl.text = originBirth;
                            // 清空输入框下方校验错误
                            _nickError.value = null;
                            _introError.value = null;

                            _genderPopVisible.value = false;
                            _birthPopVisible.value = false;
                          },
                          child: const Text(
                            "重置",
                            style: TextStyle(fontSize: 15),
                          ),
                        ),

                        SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: t.secondColor,
                          ),
                          onPressed:
                              _nickError.value == null &&
                                  _introError.value == null &&
                                  !_isSubmitting.value
                              ? updateInfo
                              : () {
                                  debugPrint(_nickError.value);
                                  debugPrint(_introError.value);
                                  debugPrint(_isSubmitting.toString());
                                  showTipSnackbar(
                                    msg: "请修正表单信息",
                                    isSuccess: false,
                                  );
                                },
                          child: const Text(
                            "保存",
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),

            Positioned(
              top: 0,
              right: 10,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, safeTop, 0, 0),
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(100, 0, 0, 0),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => updateImage(uploadType: "bgImg"),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wallpaper, color: Colors.white),
                            Text(
                              "更换背景图",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 0,
              left: 10,
              child: Container(
                // height: 150 + safeTop,
                padding: EdgeInsets.fromLTRB(0, safeTop, 0, 0),
                child: IconButton(
                  onPressed: () {
                    Get.back();
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    size: AppBase.iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            Obx(() {
              if (!_genderPopVisible.value) return SizedBox.shrink();
              return GenderSelector(
                initSelect: _selectGender,
                bgColor: t.backGroundColor,
                btnColor: t.secondColor,
                genderMap: genderMap,
                onSelect: (int selectGender) {
                  _selectGender = selectGender;
                  _genderCtrl.text = genderMap[_selectGender]!;
                },
                onVisible: (bool isVisible) {
                  _genderPopVisible.value = isVisible;
                },
              );
            }),
            Obx(() {
              if (!_birthPopVisible.value) return SizedBox.shrink();
              return BirthdaySelector(
                initialBirthStr: _selectBirth,
                bgColor: t.backGroundColor,
                btnColor: t.secondColor,
                onConfirm: (birthStr) {
                  _selectBirth = birthStr;
                  _birthCtrl.text = birthStr;
                },
                onVisible: (isVisible) {
                  _birthPopVisible.value = false;
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
