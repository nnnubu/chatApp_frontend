import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/check_input.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StrangerPreview extends StatefulWidget {
  final String targetUid;
  final bool initialIsFriend;
  const StrangerPreview({
    super.key,
    required this.targetUid,
    this.initialIsFriend = false,
  });

  @override
  State<StrangerPreview> createState() {
    return _StrangePreViewState();
  }
}

class _StrangePreViewState extends State<StrangerPreview>
    with SingleTickerProviderStateMixin {
  late ThemeController _themeController;
  late TextEditingController _msgController;
  final RxBool _addFriends = false.obs;
  final RxnString _msgError = RxnString();
  late final AnimationController _popAnimController;
  late final Animation<double> _popScaleAnim;
  late final Animation<double> _popFadeAnim;

  Future<void> addFriends() async {
    String msg = _msgController.text.trim();
    if (msg.isEmpty) {
      showTipSnackbar(msg: "请先输入验证信息", isSuccess: false);
      return;
    }
    CommonState commonState = await UserService.addFriend(
      widget.targetUid,
      msg,
    );
    if (!mounted) return;

    if (commonState.isSuccess) {
      _addFriends.value = false;
    }
    showTipSnackbar(msg: commonState.msg, isSuccess: commonState.isSuccess);
  }

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
    _msgController = TextEditingController();
    _popAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _popScaleAnim = CurvedAnimation(
      parent: _popAnimController,
      curve: Curves.easeOutBack,
    );
    _popFadeAnim = CurvedAnimation(
      parent: _popAnimController,
      curve: Curves.easeOut,
    );
    // 监听弹窗显示状态
    ever(_addFriends, (visible) {
      if (visible) {
        _popAnimController.forward();
      } else {
        _popAnimController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _popAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double safeTop = DeviceSize.instance.statusBarHeight;
    AppTheme theme = _themeController.currentTheme;
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Stack(
          children: [
            UserProfile(
              targetUid: widget.targetUid,
              themeController: _themeController,
              initialIsFriend: widget.initialIsFriend,
              onAddFriends: () {
                _addFriends.value = true;
              },
            ),
            Positioned(
              top: 0,
              left: 0,
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
              if (!_addFriends.value) return const SizedBox.shrink();
              return Positioned.fill(
                child: FadeTransition(
                  opacity: _popFadeAnim,
                  child: Stack(
                    children: [
                      Positioned.fill(child: const ColoredBox(color: Colors.black54)),
                      Center(
                        child: ScaleTransition(
                          scale: _popScaleAnim,
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 50,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              "添加好友",
                                              style: theme.headingStyle.copyWith(fontSize: 20),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Obx(() {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: theme.inputBgColor,
                                            borderRadius: BorderRadius.circular(theme.inputRadius),
                                            border: Border.all(
                                              color: _msgError.value != null ? theme.errorColor : theme.dividerColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: TextFormField(
                                            minLines: 4,
                                            maxLines: 6,
                                            controller: _msgController,
                                            keyboardType: TextInputType.multiline,
                                            textInputAction: TextInputAction.newline,
                                            style: theme.bodyStyle,
                                            decoration: InputDecoration(
                                              labelText: "打招呼内容",
                                              labelStyle: theme.captionStyle,
                                              hintText: "输入好友验证信息",
                                              alignLabelWithHint: true,
                                              border: InputBorder.none,
                                              errorText: _msgError.value,
                                              errorStyle: TextStyle(color: theme.errorColor, fontSize: 12),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                            ),
                                            onChanged: (value) {
                                              final String? err =
                                                  CheckInput.verifyMsg(value.trim());
                                              _msgError.value = err;
                                            },
                                          ),
                                        );
                                      }),

                                      const SizedBox(height: 16),

                                      // 清空按钮
                                      GestureDetector(
                                        onTap: () {
                                          _msgController.text = "";
                                        },
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(theme.buttonRadius),
                                            border: Border.all(color: theme.hintTextColor, width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "清空",
                                              style: theme.bodyStyle.copyWith(
                                                color: theme.hintTextColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // 发送按钮
                                      Obx(() {
                                        final canSend = _msgError.value == null && _msgController.text.trim().isNotEmpty;
                                        return GestureDetector(
                                          onTap: canSend ? addFriends : null,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: 48,
                                            decoration: BoxDecoration(
                                              gradient: canSend
                                                  ? LinearGradient(colors: [
                                                      theme.primaryColor,
                                                      theme.primaryColor.withOpacity(0.85),
                                                    ])
                                                  : null,
                                              color: canSend ? null : theme.hintTextColor.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(theme.buttonRadius),
                                              boxShadow: canSend
                                                  ? [
                                                      BoxShadow(
                                                        color: theme.primaryColor.withOpacity(0.4),
                                                        blurRadius: 12,
                                                        offset: const Offset(0, 6),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                "发送",
                                                style: theme.buttonStyle.copyWith(
                                                  color: canSend ? Colors.white : theme.hintTextColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                                Positioned(
                                  right: -AppBase.popBoxHorizontalPadding / 2,
                                  top: -AppBase.popBoxVerticalPadding / 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      _addFriends.value = false;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBg,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: AppBase.popCloseIconSize,
                                        color: theme.fontColor,
                                      ),
                                    ),
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
              );
            }),
          ],
        ),
      ),
    );
  }
}
