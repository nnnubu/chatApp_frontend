import 'dart:async';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/check_Input.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() {
    return _RegisterState();
  }
}

class _RegisterState extends State<Register> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  final RxInt _state = 0.obs;
  final RxInt _countDown = 60.obs;
  final RxBool _isSubmitting = false.obs;
  final RxnString _nicknameError = RxnString();
  final RxnString _pwdError = RxnString();
  final RxnString _confirmPwdError = RxnString();
  final RxnString _emailError = RxnString();
  final RxnString _codeError = RxnString();
  Timer? _countTimer;

  late final ThemeController _themeController;

  Future<void> submitForm() async {
    if (_isSubmitting.value) return;

    _isSubmitting.value = true;

    String nickname = _nameCtrl.text.trim();
    String password = _pwdCtrl.text.trim();
    String confirmPwd = _confirmPwdCtrl.text.trim();
    String email = _emailCtrl.text.trim();
    String code = _codeCtrl.text.trim();

    if (nickname.isEmpty ||
        password.isEmpty ||
        confirmPwd.isEmpty ||
        email.isEmpty ||
        code.isEmpty) {
      showTipSnackbar(msg: "请先输入表单信息", isSuccess: false);

      _isSubmitting.value = false;
      return;
    }

    final CommonState commonState = await UserService.register(
      nickname,
      password,
      email,
      code,
    );

    if (mounted) {
      _isSubmitting.value = false;
    }

    if (commonState.isSuccess && mounted) {
      // Navigator.pop(context);

      Get.back();
      // 注意这个要放在页面跳转后面，否则会导致下面的结果：
      //showTipSnackbar(msg: msg, isSuccess: isSuccess); 立刻创建Snackbar浮层
      //Get.back(); 执行Get.back，检测到Snackbar存在，只关闭弹窗，页面不退出

      //  Get.back() 有一个隐藏参数 closeOverlays = false（默认关闭），底层执行逻辑是：
      // 先检查当前是否存在Overlay 浮层（Snackbar、Dialog、BottomSheet 都属于 OverlayRoute）；
      // 如果浮层存在，优先关闭浮层，直接 return，不会执行页面 pop；
      // 只有所有浮层全部关闭后，才会弹出路由栈里的页面

      // 另外很重要的是   () async {
      //   if(mounted) Get.back();
      // }();
      // 对于这种异步匿名闭包写法，Dart 会把这个异步任务丢到事件队列，脱离生命周期，mounted容易失效，导致 Get.back() 无法正常出栈，多次操作后路由栈可能无限堆积
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
        // 页面关闭时需要手动停止 因为 Timer 是全局事件 而页面只属于 组件 事件不会因为组件被销毁而停止
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
    _nameCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = _themeController.currentTheme;
    return Scaffold(
      backgroundColor: t.backGroundColor,
      appBar: AppBar(backgroundColor: const Color.fromARGB(0, 255, 255, 255)),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: Obx(() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "注册",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                TextFormField(
                  controller: _nameCtrl,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "昵称",
                    hintText: "请输入昵称",
                    errorText: _nicknameError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  onChanged: (value) {
                    _nicknameError.value = CheckInput.nickname(value.trim());
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: true,
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
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _confirmPwdCtrl,
                  decoration: InputDecoration(
                    labelText: "确认密码",
                    hintText: "确认密码",
                    errorText: _confirmPwdError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.confirmation_num),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    if (value != _pwdCtrl.text) {
                      _confirmPwdError.value = "两次密码不一致";
                    } else {
                      _confirmPwdError.value = null;
                    }
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailCtrl,
                  obscureText: false,
                  decoration: InputDecoration(
                    labelText: "邮箱",
                    hintText: "请输入邮箱获取验证码",
                    errorText: _emailError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email),
                    suffixIcon: _state.value == 2
                        ? Padding(
                            padding: const EdgeInsetsGeometry.all(12.0),
                            child: Text(
                              "$_countDown s",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _state.value == 1 ? submitEmail : null,
                            icon: Icon(Icons.send),
                            disabledColor: Colors.grey,
                          ),
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

                const SizedBox(height: 12),

                TextFormField(
                  controller: _codeCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "验证码",
                    hintText: "请输入验证码",
                    errorText: _codeError.value,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.verified),
                  ),
                  onChanged: (value) {
                    _codeError.value = CheckInput.code(value.trim());
                  },
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: t.secondColor,
                  ),
                  onPressed:
                      _nicknameError.value == null &&
                          _pwdError.value == null &&
                          _confirmPwdError.value == null &&
                          _emailError.value == null &&
                          _codeError.value == null &&
                          !_isSubmitting.value
                      ? submitForm
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
                      return const Text("注册", style: TextStyle(fontSize: 18));
                    },
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("已有账号？"),
                    TextButton(
                      onPressed: () {
                        // Navigator.pop(context);
                        Get.back();
                      },
                      child: const Text("去登录"),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
