import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/book_controller.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/pages/book_detail.dart';
import 'package:chatapp/pages/home.dart';
import 'package:chatapp/pages/login.dart';
import 'package:chatapp/pages/profile_edit.dart';
import 'package:chatapp/pages/register.dart';
import 'package:chatapp/pages/resetpwd.dart';
import 'package:chatapp/pages/scan_qr.dart';
import 'package:chatapp/pages/splash.dart';
import 'package:chatapp/dto/dto_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  DioUtil.init();
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // 仅正常正向竖屏
  ]);

  // 限制图片缓存最大10MB，超过自动淘汰旧图
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = 10 << 20; // 10MB
  cache.maximumSize = 10; // 最多缓存10张图

  // 在 main 里面提前初始化 SharedPreferences 单例 getInstance 用于获取插件底层静态变量
  await SharedPreferences.getInstance();
  Get.put(UserController(), permanent: true);
  // 全局创建唯一控制器实例 实际是一个 Map<Type, dynamic>，它的 key 为 传入的变量的 类型 值为 该类型的 实例 permanent 默认为 true 此处显式标明该控制器为常驻控制器
  await Get.find<UserController>().loadFromStorage();
  // Get.find<UserController> 取出全局控制器实例 对应的 Get.delete<UserController> 就是 从 Map 中删除 key 为 UserController 的存储  loadFromStorage 从磁盘读取 登录信息

  // 常驻主题控制器
  Get.put(ThemeController(),permanent: true);
  // 常驻消息控制器
  Get.put(MessageController(),permanent: true);
  // 常驻图书控制器
  Get.put(BookController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 路由跳转都依赖 GetX 模块就需要吧这个 MaterialApp 改为 GetMaterialApp
    // GetX 管理路由的优势：
    // 1. 可自定义页面过渡动画
    // 2. 可在页面跳转时直接传参
    // 3. 可在main页面集中管理路由
    // Obx 监听主题变化，切换主题时自动重建整个应用
    return Obx(() {
      final themeController = Get.find<ThemeController>();
      return GetMaterialApp(
        initialRoute: "/", //自定义初始页面
        theme: themeController.themeData,
        themeMode: ThemeMode.light, // 主题由我们自己管理，不跟随系统
        // routes: {
        //   "/": (context) => const Splash(), // 写了这个路由就不需要写下面被注释掉的 home 属性了
        //   "/login": (context) => const Login(),
        //   "/register": (context) => const Register(),
        //   "/resetPwd": (context) => const ResetPwd(),
        //   "/home": (context) => const Home(),
        //   "/profileEdit": (context) => const ProfileEdit(),
        // },
        getPages: [
          GetPage(name: "/", page: () => const Splash(), curve: Curves.easeOut),
          GetPage(
            name: "/login",
            page: () => const Login(),
            transition: Transition.leftToRight,
            curve: Curves.easeOut,
          ),
          GetPage(
            name: "/register",
            page: () => const Register(),
            curve: Curves.easeOut,
          ),
          GetPage(
            name: "/resetPwd",
            page: () => const ResetPwd(),
            curve: Curves.easeOut,
          ),
          GetPage(name: "/home", page: () => const Home(), curve: Curves.easeOut),
          GetPage(
            name: "/profileEdit",
            page: () => const ProfileEdit(),
            transition: Transition.upToDown,
            curve: Curves.easeOut,
          ),
          GetPage(
            name: "/scanQR",
            page: () => const ScanQr(),
            transition: Transition.upToDown,
            curve: Curves.easeOut,
          ),
          GetPage(
            name: "/bookDetail",
            page: () => const BookDetailPage(),
            transition: Transition.rightToLeft,
            curve: Curves.easeOut,
          ),
        ],

        // defaultTransition, transitionDuration 得搭配 getPages 使用才有效 上面注释的 routes无法读取这两个全局动画配置
        defaultTransition: Transition.rightToLeft,
        transitionDuration: Duration(milliseconds: 300),

        title: 'ChatApp',
        debugShowCheckedModeBanner: false,
        // home:  Splash(),
      );
    });
  }
}
