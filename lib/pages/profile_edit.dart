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
      backgroundColor: t.scaffoldBg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                          flightShuttleBuilder:
                              (
                            BuildContext flightContext,
                            Animation<double> animation,
                            HeroFlightDirection flightDirection,
                            BuildContext fromHeroContext,
                            BuildContext toHeroContext,
                          ) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                double currentStop;
                                if (flightDirection ==
                                    HeroFlightDirection.push) {
                                  currentStop =
                                      1.0 - (animation.value * (1.0 - 0.6));
                                } else {
                                  currentStop =
                                      0.6 +
                                      (1 - animation.value) * (1.0 - 0.6);
                                }
                                return ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: shaderBegin,
                                      end: shaderEnd,
                                      colors: const [
                                        shaderOpaqueWhite,
                                        shaderTransparent,
                                      ],
                                      stops: [currentStop, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Container(
                                    decoration: const BoxDecoration(
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
                                                decoration: const BoxDecoration(
                                                  color: Colors.grey,
                                                ),
                                                child: const Icon(Icons.error),
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
                              return _bgImgGradient.createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54),
                              child: Obx(() {
                                return Image.network(
                                  buildStaticUrl(_userController.bgImg.url),
                                  cacheHeight: _userController.bgImg.thumbH,
                                  cacheWidth: _userController.bgImg.thumbW,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.grey,
                                      ),
                                      child: const Icon(Icons.error),
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
                                decoration: const BoxDecoration(
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
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                        ),
                                        child: const Icon(Icons.error),
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
                                decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: TextButton(
                                  onPressed: () =>
                                      updateImage(uploadType: "avatar"),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
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
                  padding: const EdgeInsets.all(20),
                  child: Obx(() {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 昵称
                        Container(
                          decoration: BoxDecoration(
                            color: t.inputBgColor,
                            borderRadius: BorderRadius.circular(t.inputRadius),
                            border: Border.all(
                              color: _nickError.value != null ? t.errorColor : t.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _nickCtrl,
                            style: t.bodyStyle,
                            decoration: InputDecoration(
                              labelText: "昵称",
                              hintText: "请输入昵称",
                              errorText: _nickError.value,
                              errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                              prefixIcon: Icon(Icons.person_outline, color: t.hintTextColor, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) {
                              _nickError.value = CheckInput.nickname(value.trim());
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 简介
                        Container(
                          decoration: BoxDecoration(
                            color: t.inputBgColor,
                            borderRadius: BorderRadius.circular(t.inputRadius),
                            border: Border.all(
                              color: _introError.value != null ? t.errorColor : t.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _introCtrl,
                            maxLines: 3,
                            style: t.bodyStyle,
                            decoration: InputDecoration(
                              labelText: "简介",
                              hintText: "请输入简介",
                              errorText: _introError.value,
                              errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                              prefixIcon: Icon(Icons.edit_outlined, color: t.hintTextColor, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) {
                              _introError.value = CheckInput.intro(value);
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 性别
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _genderPopVisible.value = true;
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.inputBgColor,
                              borderRadius: BorderRadius.circular(t.inputRadius),
                              border: Border.all(color: t.dividerColor, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, color: t.hintTextColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _genderCtrl.text,
                                    style: t.bodyStyle,
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: t.hintTextColor, size: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 生日
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _birthPopVisible.value = true;
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.inputBgColor,
                              borderRadius: BorderRadius.circular(t.inputRadius),
                              border: Border.all(color: t.dividerColor, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Icon(Icons.cake_outlined, color: t.hintTextColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _birthCtrl.text,
                                    style: t.bodyStyle,
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: t.hintTextColor, size: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 重置按钮
                        GestureDetector(
                          onTap: () {
                            _selectGender = originGender;
                            _selectBirth = originBirth;
                            _nickCtrl.text = originNick;
                            _introCtrl.text = originIntro;
                            _genderCtrl.text = genderMap[originGender]!;
                            _birthCtrl.text = originBirth;
                            _nickError.value = null;
                            _introError.value = null;
                            _genderPopVisible.value = false;
                            _birthPopVisible.value = false;
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(t.buttonRadius),
                              border: Border.all(color: t.hintTextColor, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                "重置",
                                style: t.bodyStyle.copyWith(
                                  color: t.hintTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 保存按钮
                        Obx(() {
                          final canSubmit = _nickError.value == null &&
                              _introError.value == null &&
                              !_isSubmitting.value;
                          return GestureDetector(
                            onTap: canSubmit
                                ? updateInfo
                                : () {
                                    showTipSnackbar(msg: "请修正表单信息", isSuccess: false);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: canSubmit
                                    ? LinearGradient(colors: [
                                        t.primaryColor,
                                        t.primaryColor.withOpacity(0.85),
                                      ])
                                    : null,
                                color: canSubmit ? null : t.hintTextColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(t.buttonRadius),
                                boxShadow: canSubmit
                                    ? [
                                        BoxShadow(
                                          color: t.primaryColor.withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _isSubmitting.value
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        "保存",
                                        style: t.buttonStyle.copyWith(fontSize: 16),
                                      ),
                              ),
                            ),
                          );
                        }),
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
                          children: const [
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
              if (!_genderPopVisible.value) return const SizedBox.shrink();
              return GenderSelector(
                initSelect: _selectGender,
                bgColor: t.scaffoldBg,
                btnColor: t.primaryColor,
                genderMap: genderMap,
                onSelect: (int selectGender) {
                  setState(() {
                    _selectGender = selectGender;
                    _genderCtrl.text = genderMap[_selectGender]!;
                  });
                },
                onVisible: (bool isVisible) {
                  _genderPopVisible.value = isVisible;
                },
              );
            }),
            Obx(() {
              if (!_birthPopVisible.value) return const SizedBox.shrink();
              return BirthdaySelector(
                initialBirthStr: _selectBirth,
                bgColor: t.scaffoldBg,
                btnColor: t.primaryColor,
                onConfirm: (birthStr) {
                  setState(() {
                    _selectBirth = birthStr;
                    _birthCtrl.text = birthStr;
                  });
                },
                onVisible: (isVisible) {
                  _birthPopVisible.value = false;
                },
              );
            }),
          ],
        ),
      ),
    ),
    );
  }
}
