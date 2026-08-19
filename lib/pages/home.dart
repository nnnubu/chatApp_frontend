import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/views/home/library.dart';
import 'package:chatapp/views/home/message.dart';
import 'package:chatapp/views/home/user_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _pageContent = [UserInfoView(), MessageView(), LibraryView()];

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() {
    return _Home();
  }
}

class _Home extends State<Home> with SingleTickerProviderStateMixin {
  int orderTab = 1;
  late PageController _pageController;
  late TabController _tabController;
  late ThemeController _themeController;
  Widget tabManager(int index) {
    return _pageContent[index];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: orderTab);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: orderTab,
    );
    _themeController = Get.find<ThemeController>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      //Scaffold 默认会给 body 子树下发一份新的媒体查询约束：强制子布局顶部预留出状态栏高度，等价于隐式给 body 外层套了一层顶部 padding，目的是：避免开发者忘记适配状态栏，导致页面内容被系统 UI 遮挡。过程：系统层给出安全区尺寸 → Scaffold 读取该数据 → 向下传递给 body 内所有子组件 → 整个 PageView、各个页面整体向下挪了状态栏的高度，关键在于滚动类组件（ListView/GridView）会自动注入顶部 MediaQuery 安全 Padding，于是这部分组件的顶部就空出一截
      body: Obx(() {
        final AppTheme t = _themeController.currentTheme;
        final safeBottom = DeviceSize.instance.bottomGestureHeight;
        return MediaQuery.removePadding(
          context: context,
          removeTop: true, // 删掉上层传来的顶部安全区padding，避免上面注释所说的内容
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      // 页面跳转时清空全局焦点，强制收起键盘
                      FocusManager.instance.primaryFocus?.unfocus();
                      _tabController.animateTo(
                        index,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.linear,
                      );
                    },
                    children: _pageContent,
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    color: t.secondColor,
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.fromLTRB(0, 0, 0, safeBottom),
                    curve: Curves.easeIn,
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black,
                      labelStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 15),
                      indicator: BoxDecoration(
                        color: t.activeColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: t.secondColor, width: 5),
                      ),
                      tabs: const [
                        Tab(text: "个人"),
                        Tab(text: "消息"),
                        Tab(text: "图书"),
                      ],
                      onTap: (int index) {
                        _pageController.jumpToPage(index);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
