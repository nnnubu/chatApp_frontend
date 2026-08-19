import 'package:chatapp/constants/app_constants.dart';
import 'package:flutter/material.dart';

const double itemHeight = 200;
const double itemMargin = 15;
const double itemRadius = 20;
const double textFontSize = 30;
const double gapRowBtn = 50;
const double btnWidth = 200;
const double btnVertPadding = 16;
const double btnRadius = 12;
const double gapSelectorBtn = 40;
const Duration animDuration = Duration(milliseconds: 200);

class GenderSelector extends StatefulWidget {
  final int? initSelect;
  final Map<int, String> genderMap;
  final Color bgColor;
  final Color btnColor;
  final void Function(int selectGender) onSelect;
  final void Function(bool isVisible) onVisible;
  const GenderSelector({
    super.key,
    this.initSelect,
    this.bgColor = Colors.white,
    this.btnColor = Colors.white,
    required this.genderMap,
    required this.onSelect,
    required this.onVisible,
  });

  @override
  State<StatefulWidget> createState() {
    return _GenderSelectorState();
  }
}

class _GenderSelectorState extends State<GenderSelector>
    with TickerProviderStateMixin {
  final Map<int, Icon> _iconMap = {
    0: Icon(Icons.hide_source),
    1: Icon(Icons.person_2),
    2: Icon(Icons.person),
  };

  late final Map<int, AnimationController> _ctrlPool;
  late final Map<int, Animation<double>> _scalePool;
  late final Map<int, Animation<int>> _colorPool;
  int? _curSelect;

  void onTapItem(int index) {
    if (_curSelect == index) return;

    if (_curSelect != null) {
      // 发送 Ticker 启动指令每帧更新控制器的 value 让 旧 item 的AnimatedBuilder 进行更新
      _ctrlPool[_curSelect]!.reverse();
    }
    _curSelect = index;
    _ctrlPool[index]!.forward(from: 0);
  }

  (Color colorBox, Color colorText) getColor(int index) {
    int colorForward = _colorPool[index]!.value;
    int colorBackward = 255 - _colorPool[index]!.value;
    Color colorBox = Color.fromARGB(
      255,
      colorBackward,
      colorBackward,
      colorBackward,
    );
    Color colorText = Color.fromARGB(
      255,
      colorForward,
      colorForward,
      colorForward,
    );
    return (colorBox, colorText);
  }

  @override
  void initState() {
    super.initState();

    _curSelect = widget.initSelect;
    _ctrlPool = {};
    _scalePool = {};
    _colorPool = {};
    List indexList = List.generate(
      widget.genderMap.length,
      (int index) => index,
    );
    for (int idx = 0; idx < widget.genderMap.length; idx++) {
      final ctrl = AnimationController(vsync: this, duration: animDuration);
      _ctrlPool[idx] = ctrl;

      _scalePool[idx] = Tween<double>(
        begin: 1,
        end: 1.2,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.linear));

      _colorPool[idx] = IntTween(
        begin: 0,
        end: 255,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeIn));
    }
    if (_curSelect != null && indexList.contains(_curSelect)) {
      _ctrlPool[_curSelect]!.forward();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _ctrlPool.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Colors.black54)),

          Center(
            child: Container(
              width: screenWidth * AppBase.popBoxWidthRatio,
              padding: const EdgeInsets.symmetric(
                vertical: AppBase.popBoxVerticalPadding,
                horizontal: AppBase.popBoxHorizontalPadding,
              ),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(AppBase.popBoxRadius),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: gapSelectorBtn),

                      Row(
                        children: List.generate(widget.genderMap.length, (
                          int index,
                        ) {
                          return KeyedSubtree(
                            key: ValueKey(index),
                            child: Expanded(
                              flex: 1,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(itemRadius),
                                onTap: () => onTapItem(index),
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _scalePool[index],
                                    _colorPool[index],
                                  ]),
                                  builder: (context, child) {
                                    // 只需要等于自己的动画值就好，因为 onTapItem 会根据当前点击的 index 和 全局的 _curSelect 来选择哪一个 Item 进行什么操作

                                    double scale = _scalePool[index]!.value;
                                    final (colorBox, colorText) = getColor(
                                      index,
                                    );

                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        margin: EdgeInsets.all(15),
                                        height: itemHeight,
                                        decoration: BoxDecoration(
                                          color: colorBox,
                                          borderRadius: BorderRadius.circular(
                                            itemRadius,
                                          ),
                                          border: Border.all(
                                            width: 1,
                                            style: BorderStyle.solid,
                                            color: colorText,
                                          ),
                                        ),
                                        // 使用 IconTheme 和 defaultTextStyle 这类无画面渲染仅为child传递动态参数的配置组件略微节省一点资源
                                        child: IconTheme(
                                          data: IconThemeData(
                                            color: colorText,
                                            size: AppBase.iconSize,
                                          ),
                                          child: DefaultTextStyle(
                                            style: TextStyle(
                                              color: colorText,
                                              fontSize: textFontSize,
                                            ),
                                            child: child!,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _iconMap[index]!,
                                        const SizedBox(height: 8),
                                        Text("${widget.genderMap[index]}"),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: gapSelectorBtn),

                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: btnVertPadding,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(btnRadius),
                            ),
                            backgroundColor: widget.btnColor,
                          ),
                          onPressed: () {
                            if (_curSelect != null) {
                              widget.onSelect(_curSelect!);
                            }
                            widget.onVisible(false);
                          },
                          child: const Text(
                            "确定",
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),
                    ],
                  ),

                  Positioned(
                    right: - AppBase.popBoxHorizontalPadding / 2,
                    top: - AppBase.popBoxVerticalPadding / 2,
                    child: IconButton(
                      onPressed: () {
                        widget.onVisible(false);
                      },
                      icon: Icon(Icons.close, size: AppBase.popCloseIconSize),
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
