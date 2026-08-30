import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // 等页面渲染完毕再执行登录校验跳转
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final userController = Get.find<UserController>();

    String targetRoute = userController.isLogin ? "/home" : "/login";

    if (userController.isLogin) {
      final token = userController.token;
      if (token.isNotEmpty) {
        await WebSocketService.instance.connect(token);
        MessageDispatcher.instance.registerHandler(DefaultMessageHandlers);
      }
    }

    if (!mounted) return;
    Get.offAllNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = _themeController.currentTheme;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: t.primaryColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: t.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 50,
                  color: t.buttonStyle.color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "ChatApp",
                style: t.titleStyle.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(t.primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "加载中...",
                style: t.captionStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
