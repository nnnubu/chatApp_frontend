import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/dto/dto_image.dart';
import 'package:chatapp/dto/dto_others.dart';
import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/views/home/user_info/collection.dart';
import 'package:chatapp/views/home/user_info/post.dart';
import 'package:chatapp/views/home/user_info/recommend.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/user_image_box.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserProfile extends StatefulWidget {
  final String targetUid;
  final ThemeController themeController;
  final VoidCallback? onAddFriends;
  final VoidCallback? onNeedQR;
  final bool initialIsFriend;
  const UserProfile({
    super.key,
    required this.targetUid,
    required this.themeController,
    this.onAddFriends,
    this.onNeedQR,
    this.initialIsFriend = false,
  });

  @override
  State<StatefulWidget> createState() {
    return _UserProfileState();
  }
}

class _UserProfileState extends State<UserProfile>
    with SingleTickerProviderStateMixin {
  late UserController _userController;

  late TabController _tabController;
  late PageController _pageController;

  // 响应式状态，替代 setState
  final RxBool _isCurrentUser = true.obs;
  final RxString _uid = "".obs;
  final RxString _nickname = "".obs;
  final RxString _intro = "".obs;
  final Rx<ImageResp> _avatar = ImageResp.fromJson({}).obs;
  final Rx<ImageResp> _bgImg = ImageResp.fromJson({}).obs;
  final RxBool _isFriend = false.obs;
  final RxString _conversationUid = "".obs;

  // 文字阴影，确保在任何背景图上都可见
  static const List<Shadow> _textShadows = [
    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
  ];

  Future<void> _loadUserInfo() async {
    String targetUid = widget.targetUid;
    if (_userController.uid == targetUid) {
      return;
    } else {
      final OtherInfoState otherInfoState = await UserService.getOtherInfo(
        targetUid,
      );
      if (!mounted) return;
      OtherUsers? targetInfo = otherInfoState.otherUserInfo;
      if (otherInfoState.isSuccess && targetInfo != null) {
        _uid.value = targetInfo.uid;
        _nickname.value = targetInfo.nickname;
        _intro.value = targetInfo.intro;
        _avatar.value = targetInfo.avatar;
        _bgImg.value = targetInfo.bgImg;
        _isFriend.value = targetInfo.isFriend;
        _conversationUid.value = targetInfo.conversationUid ?? "";
        _isCurrentUser.value = false;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _userController = Get.find<UserController>();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(initialPage: 0);
    // 先根据 targetUid 判断是否为当前用户，不依赖网络请求
    _isCurrentUser.value = _userController.uid == widget.targetUid;
    // 使用传入的初始好友关系，避免网络断开时私聊按钮消失
    _isFriend.value = widget.initialIsFriend;
    _loadUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = DeviceSize.instance.statusBarHeight;
    double screenWidth = MediaQuery.of(context).size.width;
    return Obx(() {
      final AppTheme currentTheme = widget.themeController.currentTheme;
      final isCurrent = _isCurrentUser.value;
      return Container(
        height: double.infinity,
        color: currentTheme.scaffoldBg,
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                  height: AppBase.bgImgHeight / 2 + safeTop,
                  child: Stack(
                    children: [
                      // 背景图
                      Positioned.fill(
                        child: isCurrent
                            ? Hero(
                                tag: "bgImg",
                                child: userBgImg(bgImg: _userController.bgImg),
                              )
                            : userBgImg(bgImg: _bgImg.value),
                      ),
                      // 渐变遮罩：顶部和底部加深，中间透明，确保文字可见
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black54,
                                Colors.black26,
                                Colors.black.withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 用户信息（头像、昵称、简介）
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isCurrent
                                ? Hero(
                                    tag: "avatar",
                                    child: userAvater(
                                      avatar: _userController.avatar,
                                    ),
                                  )
                                : userAvater(avatar: _avatar.value),
                            const SizedBox(height: 8),
                            isCurrent
                                ? Hero(
                                    tag: "nickname",
                                    child: Text(
                                      _userController.nickname,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        shadows: _textShadows,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _nickname.value,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      shadows: _textShadows,
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "简介: ${isCurrent ? _userController.intro : _intro.value}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      shadows: _textShadows,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // TabBar
                AnimatedContainer(
                  color: currentTheme.surfaceColor,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: currentTheme.primaryColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    labelColor: currentTheme.primaryColor,
                    unselectedLabelColor: currentTheme.hintTextColor,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    tabs: const [
                      Tab(text: "收藏"),
                      Tab(text: "推荐"),
                      Tab(text: "作品"),
                    ],
                    onTap: (int index) {
                      _pageController.jumpToPage(index);
                    },
                  ),
                ),

                // PageView
                Expanded(
                  child: Container(
                    color: currentTheme.scaffoldBg,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                      child: PageView(
                        controller: _pageController,
                        children: const [Collection(), Recommend(), Post()],
                        onPageChanged: (int index) {
                          _tabController.animateTo(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 非当前用户：底部操作栏
            if (!isCurrent)
              Positioned(
                bottom: 0,
                child: Container(
                  height: 70 + DeviceSize.instance.bottomGestureHeight,
                  width: screenWidth,
                  padding: EdgeInsets.only(
                    bottom: DeviceSize.instance.bottomGestureHeight,
                  ),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceColor,
                    border: Border(
                      top: BorderSide(color: currentTheme.dividerColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isFriend.value
                          ? Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Material(
                                  color: currentTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(currentTheme.buttonRadius),
                                  clipBehavior: Clip.hardEdge,
                                  child: InkWell(
                                    onTap: () async {
                                      String convUid = _conversationUid.value;
                                      if (convUid.isEmpty) {
                                        // 会话UID为空，尝试重新拉取用户信息
                                        await _loadUserInfo();
                                        convUid = _conversationUid.value;
                                        if (convUid.isEmpty) {
                                          Get.snackbar(
                                            "网络异常",
                                            "无法获取会话信息，请检查网络连接后重试",
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                          return;
                                        }
                                      }
                                      Get.to(
                                        () => const ChatPage(),
                                        arguments: ChatItem(
                                          uid: _uid.value,
                                          nickname: _nickname.value,
                                          avatarUrl: _avatar.value.url,
                                          conversationUid: convUid,
                                        ),
                                      );
                                    },
                                    splashColor: Colors.white.withOpacity(0.2),
                                    child: Center(
                                      child: Text(
                                        "私聊",
                                        style: currentTheme.buttonStyle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Material(
                                  color: currentTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(currentTheme.buttonRadius),
                                  clipBehavior: Clip.hardEdge,
                                  child: InkWell(
                                    onTap: () => widget.onAddFriends?.call(),
                                    splashColor: Colors.white.withOpacity(0.2),
                                    child: Center(
                                      child: Text(
                                        "添加好友",
                                        style: currentTheme.buttonStyle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
