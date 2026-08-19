import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() {
    return _Splash();
  }
}

class _Splash extends State<Splash> {
  @override
  void initState() {
    super.initState();
    // 等页面渲染完毕再执行登录校验跳转
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    final userController = Get.find<UserController>();

    String targetRoute = userController.isLogin ? "/home" : "/login";

    if (userController.isLogin) {
      final token = userController.token;
      if (token.isNotEmpty) {
        await WebSocketService.instance.connect(token);
        // 注册消息分发器
        MessageDispatcher.instance.registerHandler(DefaultMessageHandlers);
      }
    }

    if (!mounted) return;
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (context) => targetPage),
    // );
    Get.offAllNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(102, 206, 254, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(50),
              child: Image.asset("assets/images/oWo!.gif", fit: BoxFit.cover),
            ),
            const Text(
              "chatapp 加载中...",
              style: TextStyle(
                fontSize: 30,
                color: Color.fromARGB(255, 76, 0, 255),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
