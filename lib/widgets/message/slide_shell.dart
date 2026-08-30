import 'package:flutter/material.dart';

const Duration _defaultDuration = Duration(milliseconds: 200);

class SlideShell extends StatefulWidget {
  final Widget shelllAction;
  final Widget shellInChild;
  final VoidCallback shellOnTap;
  final double shellHeight;
  final double actionWidth;
  final bool needReset;
  final bool autoSlideBack;
  const SlideShell({
    super.key,
    required this.shelllAction,
    required this.shellInChild,
    required this.shellOnTap,
    required this.shellHeight,
    required this.actionWidth,
    this.needReset = false,
    this.autoSlideBack = false,
  });

  @override
  State<SlideShell> createState() {
    return _SlideShellState();
  }
}

class _SlideShellState extends State<SlideShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<double> _animX;
  double _slideX = 0;

  void slide(double targetX) {
    double dx = targetX.clamp(-widget.actionWidth, 0);
    _animX = Tween<double>(
      begin: _animX.value,
      end: dx,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn));
    _slideCtrl.forward(from: 0);
    // 更新 _slideX 的值，防止动画结束的重新渲染又跳回去
    _slideX = targetX;
  }

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: _defaultDuration);
    _animX = const AlwaysStoppedAnimation(0.0);
    if (widget.autoSlideBack) {
      _slideX = -widget.actionWidth;
      _animX = AlwaysStoppedAnimation(-widget.actionWidth);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) slide(0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SlideShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.needReset) {
      slide(0);
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.shellHeight,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            width: widget.actionWidth,
            child: widget.shelllAction,
          ),

          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                // 此处跟随手指滑动 所以需要setState来跟新
                _slideX += details.delta.dx;
                _slideX = _slideX.clamp(-widget.actionWidth, 0);
                setState(() {});
                _animX = AlwaysStoppedAnimation(_slideX);
              },
              onHorizontalDragEnd: (details) {
                // 水平速度
                double vx = details.velocity.pixelsPerSecond.dx;
                double targetX = 0;
                if (vx < -100) {
                  targetX = -widget.actionWidth;
                  slide(targetX);
                } else if (vx > 300) {
                  targetX = 0;
                  slide(targetX);
                }
              },
              onTap: () {
                if (_slideX != 0) {
                  // 此处需要更新这个为 0 因为如果点击之前 _slideX 不等于 0 那么上面判断的 dx 在动画结束之后回到原来的位置
                  _slideX = 0;
                  slide(_slideX);
                } else {
                  // debugPrint("跳转聊天界面");
                  widget.shellOnTap();
                }
              },
              child: AnimatedBuilder(
                animation: _slideCtrl,
                builder: (context, child) {
                  double dx = _slideCtrl.isAnimating ? _animX.value : _slideX;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: widget.shellInChild,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
