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

  // 底部导航图标
  static const List<IconData> _tabIcons = [
    Icons.person_outline,
    Icons.chat_bubble_outline,
    Icons.menu_book_outlined,
  ];
  static const List<IconData> _tabIconsSelected = [
    Icons.person,
    Icons.chat_bubble,
    Icons.menu_book,
  ];
  static const List<String> _tabLabels = ["个人", "消息", "图书"];

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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Obx(() {
        final AppTheme t = _themeController.currentTheme;
        final safeBottom = DeviceSize.instance.bottomGestureHeight;
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _tabController.animateTo(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    children: _pageContent,
                  ),
                ),

                // 底部导航栏
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          color: t.surfaceColor,
                          border: Border(
                            top: BorderSide(color: t.dividerColor, width: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(0, 6, 0, safeBottom),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(3, (index) {
                            final isSelected = _tabController.index == index;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _pageController.jumpToPage(index);
                                  _tabController.animateTo(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? _tabIconsSelected[index]
                                          : _tabIcons[index],
                                      color: isSelected
                                          ? t.primaryColor
                                          : t.hintTextColor,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _tabLabels[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? t.primaryColor
                                            : t.hintTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
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
