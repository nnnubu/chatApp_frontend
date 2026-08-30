import 'dart:async';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/check_input.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ResetPwd extends StatefulWidget {
  const ResetPwd({super.key});

  @override
  State<ResetPwd> createState() => _ResetPwdState();
}

class _ResetPwdState extends State<ResetPwd> {
  final TextEditingController _pwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  final RxInt _state = 0.obs;
  final RxInt _countDown = 60.obs;
  final RxBool _isSubmitting = false.obs;
  final RxnString _pwdError = RxnString();
  final RxnString _confirmPwdError = RxnString();
  final RxnString _emailError = RxnString();
  final RxnString _codeError = RxnString();
  Timer? _countTimer;

  late final ThemeController _themeController;

  Future<void> submitForm() async {
    if (_isSubmitting.value) return;

    _isSubmitting.value = true;

    String password = _pwdCtrl.text.trim();
    String confirmPwd = _confirmPwdCtrl.text.trim();
    String email = _emailCtrl.text.trim();
    String code = _codeCtrl.text.trim();

    if (password.isEmpty ||
        confirmPwd.isEmpty ||
        email.isEmpty ||
        code.isEmpty) {
      showTipSnackbar(msg: "请先输入表单信息", isSuccess: false);
      _isSubmitting.value = false;
      return;
    }

    final CommonState commonState = await UserService.resetPwd(
      email,
      code,
      password,
    );

    if (mounted) {
      _isSubmitting.value = false;
    }

    if (commonState.isSuccess && mounted) {
      Get.back();
    }
    showTipSnackbar(msg: commonState.msg, isSuccess: commonState.isSuccess);
  }

  Future<void> submitEmail() async {
    String email = _emailCtrl.text.trim();

    String? emailErr = CheckInput.email(email);
    if (emailErr != null) {
      _emailError.value = emailErr;
      return;
    }

    CommonState commonState = await UserService.sendCode(email, "resetPwd");

    if (commonState.isSuccess && mounted) {
      _state.value = 2;

      _countTimer?.cancel();
      _countTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        _countDown.value--;
        if (_countDown.value == 0) {
          timer.cancel();
          _emailError.value = CheckInput.email(_emailCtrl.text.trim());
          if (_emailError.value == null) {
            _state.value = 1;
          } else {
            _state.value = 0;
          }
          _countDown.value = 60;
        }
      });
    }

    showTipSnackbar(msg: commonState.msg, isSuccess: commonState.isSuccess);
  }

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      return Scaffold(
        backgroundColor: t.scaffoldBg,
        appBar: AppBar(
          backgroundColor: t.appBarColor,
          elevation: 0,
          iconTheme: IconThemeData(color: t.fontColor),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "重置密码",
                  style: t.titleStyle.copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "通过邮箱验证重置密码",
                  style: t.captionStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 邮箱
                TextFormField(
                  controller: _emailCtrl,
                  style: t.bodyStyle,
                  decoration: InputDecoration(
                    labelText: "邮箱",
                    labelStyle: t.captionStyle,
                    hintText: "请输入邮箱获取验证码",
                    hintStyle: t.captionStyle,
                    errorText: _emailError.value,
                    errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.email, color: t.hintTextColor),
                    suffixIcon: _state.value == 2
                        ? Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Text("${_countDown.value}s", style: t.captionStyle),
                          )
                        : IconButton(
                            onPressed: _state.value == 1 ? submitEmail : null,
                            icon: Icon(Icons.send, color: t.primaryColor),
                            disabledColor: t.hintTextColor,
                          ),
                  ),
                  onChanged: (value) {
                    _emailError.value = CheckInput.email(value.trim());
                    if (_state.value != 2) {
                      _emailError.value == null
                          ? _state.value = 1
                          : _state.value = 0;
                    }
                  },
                ),
                const SizedBox(height: 12),

                // 验证码
                TextFormField(
                  controller: _codeCtrl,
                  obscureText: true,
                  style: t.bodyStyle,
                  decoration: InputDecoration(
                    labelText: "验证码",
                    labelStyle: t.captionStyle,
                    hintText: "请输入验证码",
                    hintStyle: t.captionStyle,
                    errorText: _codeError.value,
                    errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.verified, color: t.hintTextColor),
                  ),
                  onChanged: (value) {
                    _codeError.value = CheckInput.code(value.trim());
                  },
                ),
                const SizedBox(height: 12),

                // 新密码
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  style: t.bodyStyle,
                  decoration: InputDecoration(
                    labelText: "新密码",
                    labelStyle: t.captionStyle,
                    hintText: "请输入新密码",
                    hintStyle: t.captionStyle,
                    errorText: _pwdError.value,
                    errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.key, color: t.hintTextColor),
                  ),
                  onChanged: (value) {
                    _pwdError.value = CheckInput.password(value);
                  },
                ),
                const SizedBox(height: 12),

                // 确认密码
                TextFormField(
                  controller: _confirmPwdCtrl,
                  obscureText: true,
                  style: t.bodyStyle,
                  decoration: InputDecoration(
                    labelText: "确认密码",
                    labelStyle: t.captionStyle,
                    hintText: "再次输入新密码",
                    hintStyle: t.captionStyle,
                    errorText: _confirmPwdError.value,
                    errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                    filled: true,
                    fillColor: t.inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.inputRadius),
                      borderSide: BorderSide(color: t.primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.confirmation_num, color: t.hintTextColor),
                  ),
                  onChanged: (value) {
                    if (value != _pwdCtrl.text) {
                      _confirmPwdError.value = "两次密码不一致";
                    } else {
                      _confirmPwdError.value = null;
                    }
                  },
                ),
                const SizedBox(height: 24),

                // 重置按钮
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.buttonRadius),
                    ),
                    backgroundColor: t.primaryColor,
                    elevation: 2,
                  ),
                  onPressed: _pwdError.value == null &&
                          _confirmPwdError.value == null &&
                          _emailError.value == null &&
                          _codeError.value == null &&
                          !_isSubmitting.value
                      ? submitForm
                      : () {
                          showTipSnackbar(msg: "请先修正表单信息", isSuccess: false);
                        },
                  child: _isSubmitting.value
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: t.buttonStyle.color,
                            strokeWidth: 2,
                          ),
                        )
                      : Text("重置密码", style: t.buttonStyle),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("已重置？", style: t.bodyStyle),
                    TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text(
                        "去登录",
                        style: t.bodyStyle.copyWith(
                          color: t.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
