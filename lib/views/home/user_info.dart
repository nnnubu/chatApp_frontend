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
  int themeIndex = 0;
  // 延迟加载预渲染组件
  final RxBool _preloadShaderReady = false.obs;

  Future<void> getUserQR() async {
    uploadState = await UserService.getUserQR();
    if (!mounted) return;

    if (!uploadState!.isSuccess) {
      showTipSnackbar(msg: uploadState!.msg, isSuccess: uploadState!.isSuccess);
      return;
    }

    // setState(() {
    //   _isNeedQR = true;
    // });
    // 既然使用了 obx 就不要使用 setState 了 两者的刷新会重叠，浪费性能
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
    // final userCtrl = Get.find<UserController>();
    // Obx(() { return xxx })
    // Obx内部读取 userCtrl 的响应式变量，变量修改页面自动刷新
    // 注意，Obx 的修改是会把其包裹的所有组件直接卸载重装
    // 但 Obx 的回调闭包内部 要求 必须至少读取 1 个 Rx 响应式变量，GetX 才能建立数据变更的刷新监听
    return Obx(() {
      // 响应式变量一定要在此处声明，否则会报错
      final AppTheme theme = _themeController.currentTheme;
      double screenWidth = MediaQuery.of(context).size.width;
      double safeTop = DeviceSize.instance.statusBarHeight;
      return Stack(
        children: [
          UserProfile(
            targetUid: _userController.uid,
            themeController: _themeController,
            onNeedQR: () {
              _isNeedQR.value = true;
            },
          ),

          Positioned.fill(
            child: Container(
              // height: 150 + safeTop,
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
                        // Navigator.pushReplacement(
                        //   context,
                        //   MaterialPageRoute(builder: (context) => Login()),
                        // );
                        await Get.offAllNamed("/login");
                        // 先等待跳转页面完成，再清空缓存中的个人信息，否则依赖的组件会报错,但是页面跳转之后，这各清空缓存的函数就不会触发了，所以清空缓存 放在页面跳转的前后都不行,所以决定放在跳到登录页用户发起登录请求之前再清空缓存
                        // await _userController.clearUserInfo();
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
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(builder: (context) => ProfileEdit()),
                          // );
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
                          if (themeIndex == themeTypeList.length - 1) {
                            themeIndex = 0;
                          } else {
                            themeIndex += 1;
                          }
                          _themeController.switchTheme(
                            themeTypeList[themeIndex],
                          );
                        },
                        icon: Icon(
                          Icons.sunny,
                          size: AppBase.iconSize,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

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
                        color: theme.backGroundColor,
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
          // 可预加载时，把后续的组件假如Stack中
          if (_preloadShaderReady.value)
            // Offstage 组件可以让其 child 脱离可视树，不渲染到屏幕
            // 对比 Visibility(visible:false)：Visibility 会保留占位空白区域，Offstage 直接彻底脱离布局流，不占用任何屏幕空间
            Offstage(
              offstage: true,
              child: SizedBox(
                width: double.infinity,
                height: AppBase.bgImgHeight,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    // 复用全局静态 _bgImgGradient 实例
                    return _bgImgGradient.createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  // 不将ShaderMask包裹在刷新组件内，仅内层Image响应数据更新
                  // 1. 全局固定Gradient，GPU着色程序仅编译一次并缓存，不会重复编译闪烁
                  // 2. ShaderMask全程只初始化一次，shaderCallback仅执行一次，减少CPU重复创建着色器对象开销
                  // 3. 渐变遮罩仅控制透明度渲染规则，与图片资源完全解耦，更换图片不影响遮罩效果
                  child: userBgImg(bgImg: _userController.bgImg),
                ),
              ),
            ),
        ],
      );
    });
  }
}
