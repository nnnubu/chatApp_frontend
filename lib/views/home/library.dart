import 'dart:ui';

import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _LibraryView();
  }
}

class _LibraryView extends State<LibraryView>
    with AutomaticKeepAliveClientMixin {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 获取当前设备所有渲染窗口
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    // 取主屏幕窗口
    final FlutterView view = views.first;
    // 从底层窗口读取系统安全区，单位是硬件 px，即为物理像素
    final ViewPadding pxPadding = view.viewPadding;
    // 获取当前屏幕的像素缩放倍率
    final double ratio = view.devicePixelRatio;
    // 物理像素 ÷ 像素比 = Flutter布局用的 dp(逻辑像素) 单位
    // EdgeInsets、padding 用的都是 逻辑像素
    double realTop = pxPadding.top / ratio;

    return Obx(() {
      final AppTheme t = _themeController.currentTheme;
      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(3, realTop, 0, 0),
              decoration: BoxDecoration(color: t.secondColor),
              child: Container(
                height: AppBase.topBarHeight,
                margin: EdgeInsets.fromLTRB(3, 5, 3, 10),
                decoration: BoxDecoration(
                  color: t.thirdColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextFormField(
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (String value) {
                    debugPrint("点击了搜索");
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: "搜索",
                    // contentPadding: EdgeInsets.symmetric(
                    //   horizontal: 5,
                    //   vertical: 10,
                    // ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    suffixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
                decoration: BoxDecoration(color: t.backGroundColor),
                child: GridView.builder(
                  itemCount: 10,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemBuilder: (context, index) {
                    return BookCard();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
