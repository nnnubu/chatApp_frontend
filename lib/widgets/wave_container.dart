import 'dart:ui';

import 'package:chatapp/widgets/clip/follow_wave.dart';
import 'package:flutter/material.dart';

const Duration _waveAnimDuration = Duration(milliseconds: 700);

class WaveContainer extends StatefulWidget {
  final double waveLength;
  final double waveDepth;
  final Color underBgColor;
  final Color upperBgColor;
  final int orderTab;
  final bool isConcave;
  final bool isActive;
  final List<Widget> upperContent;
  final void Function(int index) onTabChange;
  final void Function(bool isActive) onActive;
  const WaveContainer({
    super.key,
    this.underBgColor = Colors.white,
    this.upperBgColor = Colors.black,
    this.isConcave = true,
    this.isActive = false, // 由 父组件 决定当前是否激活
    required this.upperContent,
    required this.orderTab, // 由 父组件 决定初始界面在哪里
    required this.onTabChange, // 子组件 传递当前索引给 父组件
    required this.onActive, // 子组件 传递当前激活状态 给 父组件
    required this.waveLength,
    required this.waveDepth,
  });
  @override
  State<StatefulWidget> createState() {
    return _WaveContainer();
  }
}

class _WaveContainer extends State<WaveContainer>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveOffsetAnim;
  late Animation<double> _waveDepthAnim;
  late Animation<double> _waveDeclineAnim;
  FollowClipper? _cachedClipper;
  double _screenWidth = 0;
  bool _isActive = false;
  // double lastClickdx = 0;

  // 根据相应 dx 返回对应索引
  int _calcTapIndex(double dx) {
    final int itemCount = widget.upperContent.length;
    final double singleWidth = _screenWidth / itemCount;
    for (int i = 0; i < itemCount; i++) {
      double left = i * singleWidth;
      double right = (i + 1) * singleWidth;
      if (dx >= left && dx < right) {
        return i;
      }
    }
    // 默认返回 0
    return 0;
  }

  // 根据图标索引返回对应 dx
  double _getTargetXByIndex(int index) {
    final int itemCount = widget.upperContent.length;
    final double singleWidth = _screenWidth / itemCount;
    double centerX = singleWidth * index + singleWidth / 2;
    return centerX;
  }

  // double _safeX(double rawX) {
  //   final halfWave = widget.waveLength / 2;
  //   return rawX.clamp(halfWave, _screenWidth - halfWave);
  // }

  // 不再限制动画完成与否 也不设置 safeX 否则会有些对不齐
  void _updateAnimTween(double targetX) async {
    // if (_waveController.isAnimating) return;
    // double startX = lastClickdx;
    _waveDeclineAnim = Tween<double>(begin: widget.isActive ? widget.waveDepth : 0, end: 0)
        .animate(
          CurvedAnimation(
            parent: _waveController,
            curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
          ),
        );

    _waveDepthAnim = Tween<double>(begin: 0, end: widget.waveDepth).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.3, 1.0, curve: Curves.bounceIn),
      ),
    );

    double startX = _waveOffsetAnim.value;
    _waveOffsetAnim = Tween<double>(begin: startX, end: targetX).animate(
      CurvedAnimation(parent: _waveController, curve:  const Interval(0.3, 1.0, curve: Curves.elasticOut)),
    );
    await _waveController.forward(from: 0);
    // lastClickdx = targetX;
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: _waveAnimDuration,
      lowerBound: 0,
      upperBound: 1,
    );
    _waveOffsetAnim = const AlwaysStoppedAnimation(0.0);
    _waveDepthAnim = AlwaysStoppedAnimation(widget.isActive ? widget.waveDepth : 0);
    _waveDeclineAnim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWidth = MediaQuery.of(context).size.width;
    if (_screenWidth == newWidth) return;
    _screenWidth = newWidth;
    // 父组件决定了初始页面
    final centerX = _getTargetXByIndex(widget.orderTab);
    _waveOffsetAnim = Tween(begin: centerX, end: centerX).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.elasticOut),
    );
    // lastClickdx = _screenWidth / 2;
  }

  // 使用 covariant，从原参数类型 Widget 缩小参数类型为 WaveContainer，可访问自定义字段
  @override
  void didUpdateWidget(covariant WaveContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父组件页面跳转需要用到
    // if (oldWidget.orderTab != widget.orderTab) {
    //   final targetX = _getTargetXByIndex(widget.orderTab);
    //   _updateAnimTween(targetX);
    // }

    if (oldWidget.isActive != widget.isActive) {
      _isActive = widget.isActive;
      if (!_isActive) {
        // 锁死X位移，全程固定当前坐标，不再做任何X轴运动
        double currentX = _waveOffsetAnim.value;
        _waveOffsetAnim = AlwaysStoppedAnimation(currentX);

        // 关闭：波浪深度动画归零，波浪消失
        _waveDepthAnim = Tween<double>(begin: _waveDepthAnim.value, end: 0)
            .animate(
              CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
            );
        _waveController.forward(from: 0);
      }
      // 标记裁剪器失效，强制重建
      _cachedClipper = null;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: widget.waveDepth,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: widget.underBgColor,
                  height: widget.waveDepth,
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: widget.upperContent.map((_) {
                  return Column(
                    children: [
                      SizedBox(height: widget.waveDepth - 25),
                      Icon(Icons.circle, color: widget.upperBgColor),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        AnimatedBuilder(
          animation: Listenable.merge(
            [_waveOffsetAnim, _waveDepthAnim, _waveDeclineAnim],
          ), // 同时监听两个动画，如果只监听一个，且被建通实例是 AlwaysStoppedAnimation 的，那就不会触发 builder，会导致另一个动画无法被正常渲染
          builder: (context, child) {
            // 参数没变就复用旧实例 防止父组件在setState时频繁创建实例
            final currentClick = _waveOffsetAnim.value;
            final wLen = widget.waveLength;
            final wDep = widget.waveDepth;
            double realDepth  = _waveDepthAnim.value + _waveDeclineAnim.value;
            realDepth  = realDepth .clamp(0.0, widget.waveDepth);

            if (_cachedClipper == null ||
                _cachedClipper!.clickdx != currentClick ||
                _cachedClipper!.waveLength != wLen ||
                _cachedClipper!.waveDepth != _waveDepthAnim.value ||
                _cachedClipper!.isTraceable != _isActive ||
                _cachedClipper!.isConcave != widget.isConcave) {
              _cachedClipper = FollowClipper(
                clickdx: currentClick,
                waveLength: wLen,
                waveDepth: realDepth,
                isConcave: widget.isConcave,
                isTraceable: _isActive,
              );
            }
            return ClipPath(
              clipper: _cachedClipper,
              child: GestureDetector(
                onTapDown: (TapDownDetails details) {
                  final double dx = details.localPosition.dx;
                  final newIndex = _calcTapIndex(dx);
                  // 将当前激活图标索引传递给父组件
                  _isActive = true;
                  widget.onTabChange(newIndex);
                  widget.onActive(_isActive);
                  final double targetX = _getTargetXByIndex(newIndex);
                  _updateAnimTween(targetX);
                },
                child: Container(
                  color: widget.upperBgColor,
                  height: wDep,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: widget.upperContent,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
