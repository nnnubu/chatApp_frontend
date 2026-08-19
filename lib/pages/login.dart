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

class _Login extends State<Login> {
  late final UserController userController;
  late final AppTheme theme;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pwdCtrl;

  final RxBool _isSubmitting = false.obs;
  final RxnString _emailError = RxnString();
  final RxnString _pwdError = RxnString();

  @override
  void initState() {
    super.initState();
    userController = Get.find<UserController>();
    theme = Get.find<ThemeController>().currentTheme;
    _emailCtrl = TextEditingController();
    _pwdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
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
      // 异步等待的间隙，用户可能会退出页面，因此后续的操作如果涉及context，就需要进行mounted判断
      // if (!mounted) return;
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => Home()),
      // );
      Get.offAllNamed("/home");
    }

    showTipSnackbar(msg: loginState.msg, isSuccess: loginState.isSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backGroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24, //水平
            vertical: 80, //垂直
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Column 的主轴是垂直方向。crossAxis即为交叉轴，也就是在水平方向 stretch 拉伸填满父组件
            children: [
              const Text(
                "登录",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              Obx(() {
                return TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "邮箱",
                    hintText: "请输入邮箱",
                    errorText: _emailError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  onChanged: (value) {
                    _emailError.value = CheckInput.email(value.trim());
                  },
                );
              }),

              const SizedBox(height: 12),

              Obx(() {
                return TextFormField(
                  controller: _pwdCtrl,
                  obscureText: true, //是否可见
                  decoration: InputDecoration(
                    labelText: "密码",
                    hintText: "请输入密码",
                    errorText: _pwdError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.key),
                  ),
                  onChanged: (value) {
                    _pwdError.value = CheckInput.password(value);
                  },
                );
              }),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) =>
                    //         RegisterOrResetPwd(isResetPassword: true),
                    //   ),

                    // );
                    Get.toNamed("/resetPwd");
                  },
                  child: const Text("忘记密码？"),
                ),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: theme.secondColor,
                ),
                onPressed:
                    _emailError.value == null &&
                        _pwdError.value == null &&
                        !_isSubmitting.value
                    ? submitLogin
                    : () {
                        showTipSnackbar(msg: "请先修正表单信息", isSuccess: false);
                      },
                child: Builder(
                  builder: (context) {
                    if (_isSubmitting.value) {
                      return CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      );
                    }
                    return const Text("登录", style: TextStyle(fontSize: 18));
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("还没有账号？"),
                  TextButton(
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => RegisterOrResetPwd(),
                      //   ),
                      // );

                      Get.toNamed("/register");
                    },
                    child: const Text("去注册"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
