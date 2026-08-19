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
  const StrangerPreview({super.key, required this.targetUid});

  @override
  State<StrangerPreview> createState() {
    return _StrangePreViewState();
  }
}

class _StrangePreViewState extends State<StrangerPreview> {
  late ThemeController _themeController;
  late TextEditingController _msgController;
  final RxBool _addFriends = false.obs;
  final RxnString _msgError = RxnString();

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
  }

  @override
  void dispose() {
    _msgController.dispose();
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
              onAddFriends: () {
                _addFriends.value = true;
              },
            ),
            Positioned(
              top: 0,
              left: 0,
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
              if (!_addFriends.value) return SizedBox.shrink();
              return Positioned.fill(
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
                            Padding(
                              padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
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
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Obx(() {
                                    return TextFormField(
                                      minLines: 8,
                                      maxLines: 10, // 设置null代表无限扩展
                                      expands:
                                          false, // expands:true 要求强行占满父容器高度，和自动换行互斥，只能用于占据整块区域的输入框
                                      controller: _msgController,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction:
                                          TextInputAction.newline, // 回车换行
                                      decoration: InputDecoration(
                                        // labelText: "打招呼内容",
                                        label: Text(
                                          "打招呼内容",
                                          style: TextStyle(fontSize: 25),
                                        ),
                                        hintText: "输入好友验证信息",
                                        alignLabelWithHint: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        errorText: _msgError.value,
                                      ),
                                      onChanged: (value) {
                                        final String? err =
                                            CheckInput.verifyMsg(value.trim());
                                        _msgError.value = err;
                                      },
                                    );
                                  }),

                                  SizedBox(height: 10),

                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: theme.secondColor,
                                    ),
                                    onPressed: () {
                                      _msgController.text = "";
                                    },
                                    child: const Text(
                                      "清空",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),

                                  SizedBox(height: 10),

                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: theme.secondColor,
                                    ),
                                    onPressed: _msgError.value == null
                                        ? addFriends
                                        : null,
                                    child: const Text(
                                      "发送",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Positioned(
                              right: -AppBase.popBoxHorizontalPadding / 2,
                              top: -AppBase.popBoxVerticalPadding / 2,
                              child: IconButton(
                                onPressed: () {
                                  _addFriends.value = false;
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
              );
            }),
          ],
        ),
      ),
    );
  }
}
