import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/build_static_url.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/user_image_box.dart';
import 'package:chatapp/widgets/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

final Gradient _bgImgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Colors.white, Color(0x00FFFFFF)],
  stops: const [0.6, 1],
);

class UserInfoView extends StatefulWidget {
  const UserInfoView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _UserInfoViewState();
  }
}

class _UserInfoViewState extends State<UserInfoView>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late UserController _userController;
  late ThemeController _themeController;
  final RxBool _isNeedQR = false.obs;
  UploadState? uploadState;
  List themeTypeList = ThemeType.values;
  // 延迟加载预渲染组件
  final RxBool _preloadShaderReady = false.obs;

  // 每个主题对应的图标
  IconData _themeIcon(ThemeType type) {
    switch (type) {
      case ThemeType.freshGreen:
        return Icons.eco;
      case ThemeType.warmVintageT:
        return Icons.local_cafe;
      case ThemeType.darkTheme:
        return Icons.nightlight_round;
      case ThemeType.oceanBlue:
        return Icons.water;
      case ThemeType.sakuraPink:
        return Icons.local_florist;
      case ThemeType.midnightPurple:
        return Icons.bedtime;
      case ThemeType.minimalWhite:
        return Icons.wb_sunny;
      case ThemeType.sunsetOrange:
        return Icons.wb_twilight;
    }
  }

  Future<void> getUserQR() async {
    uploadState = await UserService.getUserQR();
    if (!mounted) return;

    if (!uploadState!.isSuccess) {
      showTipSnackbar(msg: uploadState!.msg, isSuccess: uploadState!.isSuccess);
      return;
    }

    _isNeedQR.value = true;
  }

  @override
  void initState() {
    super.initState();
    _userController = Get.find<UserController>();
    _themeController = Get.find<ThemeController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadShaderReady.value = true;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final AppTheme theme = _themeController.currentTheme;
      double screenWidth = MediaQuery.of(context).size.width;
      double safeTop = DeviceSize.instance.statusBarHeight;
      return Stack(
        children: [
          // UserProfile 占满整个 Stack，确保内部 Expanded 正确计算高度
          Positioned.fill(
            child: UserProfile(
              targetUid: _userController.uid,
              themeController: _themeController,
              onNeedQR: () {
                _isNeedQR.value = true;
              },
            ),
          ),

          // 顶部按钮栏（退出、编辑、二维码、主题切换）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(0, safeTop, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.rotate(
                    angle: 3.14,
                    child: IconButton(
                      onPressed: () async {
                        if (!mounted) return;
                        await Get.offAllNamed("/login");
                      },
                      icon: Icon(
                        Icons.exit_to_app,
                        size: AppBase.iconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Get.toNamed("/profileEdit");
                        },
                        icon: Icon(
                          Icons.edit,
                          size: AppBase.iconSize,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          getUserQR();
                        },
                        icon: Icon(
                          Icons.qr_code,
                          size: AppBase.iconSize,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final currentIdx = themeTypeList.indexOf(_themeController.currentType);
                          final nextIdx = (currentIdx + 1) % themeTypeList.length;
                          _themeController.switchTheme(themeTypeList[nextIdx]);
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) {
                            return RotationTransition(
                              turns: Tween<double>(begin: 0.5, end: 1.0).animate(anim),
                              child: FadeTransition(opacity: anim, child: child),
                            );
                          },
                          child: Icon(
                            _themeIcon(_themeController.currentType),
                            key: ValueKey(_themeController.currentType),
                            size: AppBase.iconSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 二维码弹窗
          if (_isNeedQR.value)
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black54)),
                  Center(
                    child: Container(
                      width: screenWidth * AppBase.popBoxWidthRatio,
                      padding: EdgeInsets.symmetric(
                        vertical: AppBase.popBoxVerticalPadding,
                        horizontal: AppBase.popBoxHorizontalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBg,
                        borderRadius: BorderRadius.circular(
                          AppBase.popBoxRadius,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Builder(
                            builder: (context) {
                              final imgResp = uploadState?.imageResp;
                              if (imgResp == null) return const SizedBox();
                              return Image.network(
                                buildStaticUrl(imgResp.url),
                                cacheHeight: imgResp.thumbH,
                                cacheWidth: imgResp.thumbW,
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
                            },
                          ),
                          Positioned(
                            right: -AppBase.popBoxHorizontalPadding / 2,
                            top: -AppBase.popBoxVerticalPadding / 2,
                            child: IconButton(
                              onPressed: () {
                                _isNeedQR.value = false;
                              },
                              icon: Icon(
                                Icons.close,
                                size: AppBase.popCloseIconSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 预加载着色器
          if (_preloadShaderReady.value)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: double.infinity,
                height: AppBase.bgImgHeight,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return _bgImgGradient.createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: userBgImg(bgImg: _userController.bgImg),
                ),
              ),
            ),
        ],
      );
    });
  }
}
