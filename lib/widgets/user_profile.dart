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
  const UserProfile({
    super.key,
    required this.targetUid,
    required this.themeController,
    this.onAddFriends,
    this.onNeedQR,
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

  bool _isCurrentUser = true;

  String _uid = "";
  String _nickname = "";
  String _intro = "";
  ImageResp _avatar = ImageResp.fromJson({});
  ImageResp _bgImg = ImageResp.fromJson({});
  bool _isFriend = false;
  String? _conversationUid;

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
        _uid = targetInfo.uid;
        _nickname = targetInfo.nickname;
        _intro = targetInfo.intro;
        _avatar = targetInfo.avatar;
        _bgImg = targetInfo.bgImg;
        _isFriend = targetInfo.isFriend;
        _conversationUid = targetInfo.conversationUid;

        _isCurrentUser = false;
        setState(() {});
      }
    }
  }

  // UserProfie State里重写didChangeDependencies（生命周期上下文就绪，不会抛依赖报错）
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _userController = Get.find<UserController>();
    // length 代表 tab 元素的个数
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(initialPage: 0);
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
    final AppTheme currentTheme = widget.themeController.currentTheme;
    final safeTop = DeviceSize.instance.statusBarHeight;
    double screenWidth = MediaQuery.of(context).size.width;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      color: currentTheme.backGroundColor,
      curve: Curves.easeIn,
      child: Stack(
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeIn,
                height: AppBase.bgImgHeight / 2 + safeTop,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _isCurrentUser
                          ? Hero(
                              tag: "bgImg",
                              child: userBgImg(bgImg: _userController.bgImg),
                            )
                          : userBgImg(bgImg: _bgImg),
                    ),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isCurrentUser
                              ? Hero(
                                  tag: "avatar",
                                  child: userAvater(
                                    avatar: _userController.avatar,
                                  ),
                                )
                              : userAvater(avatar: _avatar),
                          _isCurrentUser
                              ? Hero(
                                  tag: "nickname",
                                  child: Text(
                                    _userController.nickname,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 35,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Text(
                                      _nickname,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 35,
                                      ),
                                    ),
                                  ],
                                ),

                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              "简介:${_isCurrentUser ? _userController.intro : _intro}",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedContainer(
                color: currentTheme.secondColor,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: currentTheme.activeColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black,
                  labelStyle: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 15),
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

              Expanded(
                child: Padding(
                  padding: EdgeInsetsGeometry.fromLTRB(10, 5, 10, 0),
                  child: PageView(
                    controller: _pageController,
                    children: [Collection(), Recommend(), Post()],
                    onPageChanged: (int index) {
                      _tabController.animateTo(
                        index,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.linear,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          if (!_isCurrentUser)
            Positioned(
              bottom: 0,
              child: Container(
                height: 70,
                width: screenWidth,
                decoration: BoxDecoration(color: currentTheme.backGroundColor),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isFriend && _conversationUid != ""
                        ? Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsetsGeometry.all(5),
                              child: Material(
                                color: currentTheme.secondColor,
                                borderRadius: BorderRadius.circular(10),
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  onTap: () {
                                    // 其实此处可以用 targetUid
                                    // 毕竟已经判断不是当前用户了
                                    // 但还是用后端返回的结果稳当些
                                    Get.to(
                                      () => ChatPage(),
                                      arguments: ChatItem(
                                        uid: _uid,
                                        nickname: _nickname,
                                        avatarUrl: _avatar.url,
                                        conversationUid: _conversationUid,
                                      ),
                                    );
                                  },
                                  splashColor: currentTheme.backGroundColor,
                                  child: Center(child: Text("私聊")),
                                ),
                              ),
                            ),
                          )
                        : Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsetsGeometry.all(5),
                              child: Material(
                                color: currentTheme.secondColor,
                                borderRadius: BorderRadius.circular(10),
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  onTap: () => widget.onAddFriends?.call(),
                                  splashColor: currentTheme.backGroundColor,
                                  child: Center(child: Text("添加好友")),
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
  }
}
