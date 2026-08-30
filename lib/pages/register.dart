import 'dart:async';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/check_input.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<StatefulWidget> createState() {
    return _RegisterState();
  }
}

class _RegisterState extends State<Register> with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  final RxnString _nicknameError = RxnString();
  final RxnString _pwdError = RxnString();
  final RxnString _confirmPwdError = RxnString();
  final RxnString _emailError = RxnString();
  final RxnString _codeError = RxnString();

  // 0: 邮箱未验证 1: 可发送验证码 2: 倒计时中
  final RxInt _state = 0.obs;
  final RxBool _isSubmitting = false.obs;
  final RxInt _countDown = 60.obs;
  final RxBool _obscurePwd = true.obs;
  final RxBool _obscureConfirmPwd = true.obs;

  Timer? _countTimer;
  late ThemeController _themeController;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  Future<void> submitForm() async {
    _isSubmitting.value = true;
    CommonState commonState = await UserService.register(
      _nameCtrl.text.trim(),
      _pwdCtrl.text,
      _emailCtrl.text.trim(),
      _codeCtrl.text.trim(),
    );
    if (!mounted) return;
    _isSubmitting.value = false;

    if (commonState.isSuccess) {
      // 注册成功，返回登录页
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

    CommonState commonState = await UserService.sendCode(email, "register");
    if (!mounted) return;

    if (commonState.isSuccess) {
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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _countTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required RxnString error,
    required Function(String) onChanged,
    bool obscureText = false,
    RxBool? obscureController,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      return Container(
        decoration: BoxDecoration(
          color: t.inputBgColor,
          borderRadius: BorderRadius.circular(t.inputRadius),
          border: Border.all(
            color: error.value != null ? t.errorColor : t.dividerColor,
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText && (obscureController?.value ?? true),
          keyboardType: keyboardType,
          style: t.bodyStyle,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: t.captionStyle,
            hintText: hint,
            hintStyle: t.captionStyle,
            errorText: error.value,
            errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
            prefixIcon: Icon(icon, color: t.hintTextColor, size: 20),
            suffixIcon: obscureController != null
                ? IconButton(
                    icon: Icon(
                      obscureController.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: t.hintTextColor,
                      size: 18,
                    ),
                    onPressed: onToggleObscure,
                  )
                : suffix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: onChanged,
        ),
      );
    });
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
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "创建账号",
                      style: t.titleStyle.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "加入我们，开始聊天",
                      style: t.captionStyle.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // 昵称
                    _buildInputField(
                      controller: _nameCtrl,
                      label: "昵称",
                      hint: "请输入昵称",
                      icon: Icons.person_outline,
                      error: _nicknameError,
                      onChanged: (value) =>
                          _nicknameError.value = CheckInput.nickname(value.trim()),
                    ),
                    const SizedBox(height: 14),

                    // 密码
                    _buildInputField(
                      controller: _pwdCtrl,
                      label: "密码",
                      hint: "请输入密码",
                      icon: Icons.lock_outline,
                      error: _pwdError,
                      obscureText: true,
                      obscureController: _obscurePwd,
                      onToggleObscure: () => _obscurePwd.value = !_obscurePwd.value,
                      onChanged: (value) => _pwdError.value = CheckInput.password(value),
                    ),
                    const SizedBox(height: 14),

                    // 确认密码
                    _buildInputField(
                      controller: _confirmPwdCtrl,
                      label: "确认密码",
                      hint: "再次输入密码",
                      icon: Icons.lock_outline,
                      error: _confirmPwdError,
                      obscureText: true,
                      obscureController: _obscureConfirmPwd,
                      onToggleObscure: () =>
                          _obscureConfirmPwd.value = !_obscureConfirmPwd.value,
                      onChanged: (value) {
                        if (value != _pwdCtrl.text) {
                          _confirmPwdError.value = "两次密码不一致";
                        } else {
                          _confirmPwdError.value = null;
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // 邮箱 + 验证码按钮
                    Obx(() {
                      return Container(
                        decoration: BoxDecoration(
                          color: t.inputBgColor,
                          borderRadius: BorderRadius.circular(t.inputRadius),
                          border: Border.all(
                            color: _emailError.value != null ? t.errorColor : t.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: t.bodyStyle,
                          decoration: InputDecoration(
                            labelText: "邮箱",
                            labelStyle: t.captionStyle,
                            hintText: "请输入邮箱获取验证码",
                            hintStyle: t.captionStyle,
                            errorText: _emailError.value,
                            errorStyle: TextStyle(color: t.errorColor, fontSize: 12),
                            prefixIcon: Icon(Icons.email_outlined, color: t.hintTextColor, size: 20),
                            suffixIcon: _state.value == 2
                                ? Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Text(
                                      "${_countDown.value}s",
                                      style: t.captionStyle,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _state.value == 1 ? submitEmail : null,
                                    child: Text(
                                      "获取验证码",
                                      style: TextStyle(
                                        color: _state.value == 1 ? t.primaryColor : t.hintTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onChanged: (value) {
                            _emailError.value = CheckInput.email(value.trim());
                            if (_state.value != 2) {
                              if (_emailError.value == null) {
                                _state.value = 1;
                              } else {
                                _state.value = 0;
                              }
                            }
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 14),

                    // 验证码
                    _buildInputField(
                      controller: _codeCtrl,
                      label: "验证码",
                      hint: "请输入验证码",
                      icon: Icons.verified_outlined,
                      error: _codeError,
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _codeError.value = CheckInput.code(value.trim()),
                    ),
                    const SizedBox(height: 28),

                    // 注册按钮
                    Obx(() {
                      final canSubmit = _nicknameError.value == null &&
                          _pwdError.value == null &&
                          _confirmPwdError.value == null &&
                          _emailError.value == null &&
                          _codeError.value == null &&
                          !_isSubmitting.value;
                      return GestureDetector(
                        onTap: canSubmit
                            ? submitForm
                            : () {
                                showTipSnackbar(msg: "请先修正表单信息", isSuccess: false);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: canSubmit
                                ? LinearGradient(
                                    colors: [
                                      t.primaryColor,
                                      t.primaryColor.withOpacity(0.85),
                                    ],
                                  )
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
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    "注册",
                                    style: t.buttonStyle.copyWith(fontSize: 16),
                                  ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // 去登录
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("已有账号？", style: t.bodyStyle.copyWith(fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            Get.back();
                          },
                          child: Text(
                            "去登录",
                            style: t.bodyStyle.copyWith(
                              color: t.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
