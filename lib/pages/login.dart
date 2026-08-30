import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/utils/storage.dart';
import 'package:chatapp/utils/check_input.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() {
    return _Login();
  }
}

class _Login extends State<Login> with SingleTickerProviderStateMixin {
  late final UserController userController;
  late final ThemeController themeController;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pwdCtrl;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final RxBool _isSubmitting = false.obs;
  final RxnString _emailError = RxnString();
  final RxnString _pwdError = RxnString();
  final RxBool _obscurePwd = true.obs;

  @override
  void initState() {
    super.initState();
    userController = Get.find<UserController>();
    themeController = Get.find<ThemeController>();
    _emailCtrl = TextEditingController();
    _pwdCtrl = TextEditingController();
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
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> submitLogin() async {
    if (_isSubmitting.value) return;

    _isSubmitting.value = true;

    String email = _emailCtrl.text.trim();
    String password = _pwdCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showTipSnackbar(msg: "请先输入表单信息", isSuccess: false);
      _isSubmitting.value = false;

      return;
    }
    // 发起登录请求之前，清空上一个用户的缓存信息，并关闭其 ws 连接
    await userController.clearUserInfo();
    await Get.find<MessageController>().clearInfo();
    await WebSocketService.instance.disConnect();

    final LoginState loginState = await UserService.login(email, password);

    if (mounted) {
      _isSubmitting.value = false;
    }

    if (loginState.isSuccess && loginState.loginResponse != null) {
      await saveLoginData(loginState.loginResponse!);
      userController.setUserInfo(loginState.loginResponse!);
      final token = userController.token;
      if (token.isNotEmpty) {
        await WebSocketService.instance.connect(token);
        // 注册消息分发器
        MessageDispatcher.instance.registerHandler(DefaultMessageHandlers);
      }
      Get.offAllNamed("/home");
    }

    showTipSnackbar(msg: loginState.msg, isSuccess: loginState.isSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AppTheme theme = themeController.currentTheme;

      return Scaffold(
        backgroundColor: theme.scaffoldBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Logo 区域
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "欢迎回来",
                      style: theme.titleStyle.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "登录以继续使用",
                      style: theme.captionStyle.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // 邮箱输入框
                    Obx(() {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.inputBgColor,
                          borderRadius: BorderRadius.circular(theme.inputRadius),
                          border: Border.all(
                            color: _emailError.value != null
                                ? theme.errorColor
                                : theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: theme.bodyStyle,
                          decoration: InputDecoration(
                            labelText: "邮箱",
                            hintText: "请输入邮箱",
                            errorText: _emailError.value,
                            errorStyle: TextStyle(color: theme.errorColor, fontSize: 12),
                            prefixIcon: Icon(Icons.email_outlined, color: theme.hintTextColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onChanged: (value) {
                            _emailError.value = CheckInput.email(value.trim());
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // 密码输入框
                    Obx(() {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.inputBgColor,
                          borderRadius: BorderRadius.circular(theme.inputRadius),
                          border: Border.all(
                            color: _pwdError.value != null
                                ? theme.errorColor
                                : theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _pwdCtrl,
                          obscureText: _obscurePwd.value,
                          style: theme.bodyStyle,
                          decoration: InputDecoration(
                            labelText: "密码",
                            hintText: "请输入密码",
                            errorText: _pwdError.value,
                            errorStyle: TextStyle(color: theme.errorColor, fontSize: 12),
                            prefixIcon: Icon(Icons.lock_outline, color: theme.hintTextColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePwd.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: theme.hintTextColor,
                                size: 20,
                              ),
                              onPressed: () => _obscurePwd.value = !_obscurePwd.value,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onChanged: (value) {
                            _pwdError.value = CheckInput.password(value);
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Get.toNamed("/resetPwd");
                        },
                        child: Text("忘记密码？", style: TextStyle(color: theme.primaryColor, fontSize: 13)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 登录按钮
                    Obx(() {
                      final canSubmit = _emailError.value == null &&
                          _pwdError.value == null &&
                          !_isSubmitting.value;
                      return GestureDetector(
                        onTap: canSubmit
                            ? submitLogin
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
                                      theme.primaryColor,
                                      theme.primaryColor.withOpacity(0.85),
                                    ],
                                  )
                                : null,
                            color: canSubmit ? null : theme.hintTextColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(theme.buttonRadius),
                            boxShadow: canSubmit
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
                                    "登录",
                                    style: theme.buttonStyle.copyWith(fontSize: 16),
                                  ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // 注册入口
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("还没有账号？", style: theme.bodyStyle.copyWith(fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            Get.toNamed("/register");
                          },
                          child: Text(
                            "去注册",
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 14,
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
          ),
        ),
      );
    });
  }
}
