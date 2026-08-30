import 'package:chatapp/widgets/clip/follow_wave.dart';
import 'package:flutter/material.dart';

const Duration _waveAnimDuration = Duration(milliseconds: 500);

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
    this.isActive = false,
    required this.upperContent,
    required this.orderTab,
    required this.onTabChange,
    required this.onActive,
    required this.waveLength,
    required this.waveDepth,
  });

  @override
  State<StatefulWidget> createState() => _WaveContainerState();
}

class _WaveContainerState extends State<WaveContainer>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveOffsetAnim;
  late Animation<double> _waveDepthAnim;
  FollowClipper? _cachedClipper;
  double _screenWidth = 0;
  bool _isActive = false;

  // 根据 dx 返回对应索引
  int _calcTapIndex(double dx) {
    final int itemCount = widget.upperContent.length;
    if (itemCount == 0) return 0;
    final double singleWidth = _screenWidth / itemCount;
    final index = (dx / singleWidth).floor();
    return index.clamp(0, itemCount - 1);
  }

  // 根据索引返回目标中心 X
  double _getTargetXByIndex(int index) {
    final int itemCount = widget.upperContent.length;
    if (itemCount == 0) return 0;
    final double singleWidth = _screenWidth / itemCount;
    return singleWidth * index + singleWidth / 2;
  }

  // 点击切换分类：波浪深度保持，X 位置平滑移动
  void _moveWaveTo(double targetX) {
    final double startX = _waveOffsetAnim.value;

    _waveDepthAnim = AlwaysStoppedAnimation(widget.waveDepth);

    _waveOffsetAnim = Tween<double>(begin: startX, end: targetX).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );

    _waveController.forward(from: 0);
  }

  // 收起：X 位置锁死在原地，只有深度归零
  void _collapseWave() {
    final double currentX = _waveOffsetAnim.value;
    // 锁死 X 位移，全程固定当前坐标，不再做任何 X 轴运动
    _waveOffsetAnim = AlwaysStoppedAnimation(currentX);

    _waveDepthAnim = Tween<double>(
      begin: _waveDepthAnim.value,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    _waveController.forward(from: 0);
  }

  // 展开：深度从 0 升到 waveDepth，位置在当前 orderTab
  void _expandWave() {
    final targetX = _getTargetXByIndex(widget.orderTab);
    _waveOffsetAnim = AlwaysStoppedAnimation(targetX);

    _waveDepthAnim = Tween<double>(
      begin: 0,
      end: widget.waveDepth,
    ).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    _waveController.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: _waveAnimDuration,
    );
    _waveOffsetAnim = const AlwaysStoppedAnimation(0.0);
    _waveDepthAnim = AlwaysStoppedAnimation(
      widget.isActive ? widget.waveDepth : 0,
    );
    _isActive = widget.isActive;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWidth = MediaQuery.of(context).size.width;
    if (_screenWidth == newWidth) return;
    _screenWidth = newWidth;
    final centerX = _getTargetXByIndex(widget.orderTab);
    _waveOffsetAnim = AlwaysStoppedAnimation(centerX);
  }

  @override
  void didUpdateWidget(covariant WaveContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // isActive 状态变化：展开或收起
    if (oldWidget.isActive != widget.isActive) {
      _isActive = widget.isActive;
      if (_isActive) {
        // 展开：绘制波浪
        _expandWave();
      } else {
        // 收起：原地关闭，X 位置不变
        _collapseWave();
      }
      _cachedClipper = null;
      return;
    }

    // 已激活状态下，orderTab 变化（父组件切换分类）：移动波浪
    if (_isActive && oldWidget.orderTab != widget.orderTab) {
      final targetX = _getTargetXByIndex(widget.orderTab);
      _moveWaveTo(targetX);
      _cachedClipper = null;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  // 处理点击
  void _handleTap(TapUpDetails details) {
    final double dx = details.localPosition.dx;
    final newIndex = _calcTapIndex(dx);

    _isActive = true;
    widget.onTabChange(newIndex);
    widget.onActive(true);

    final double targetX = _getTargetXByIndex(newIndex);
    _moveWaveTo(targetX);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.waveDepth,
      // GestureDetector 放在最外层，确保整个区域可点击
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTap,
        child: Stack(
          children: [
            // 底层
            Container(
              height: widget.waveDepth,
              color: widget.underBgColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: widget.upperContent.map((_) {
                  return Column(
                    children: [
                      SizedBox(height: widget.waveDepth - 20),
                      Icon(Icons.circle, size: 6, color: widget.upperBgColor),
                    ],
                  );
                }).toList(),
              ),
            ),

            // 上层（带波浪裁剪）
            AnimatedBuilder(
              animation: Listenable.merge([_waveOffsetAnim, _waveDepthAnim]),
              builder: (context, child) {
                final currentClick = _waveOffsetAnim.value;
                final wLen = widget.waveLength;
                final realDepth =
                    _waveDepthAnim.value.clamp(0.0, widget.waveDepth);

                if (_cachedClipper == null ||
                    _cachedClipper!.clickdx != currentClick ||
                    _cachedClipper!.waveLength != wLen ||
                    _cachedClipper!.waveDepth != realDepth ||
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
                  child: Container(
                    color: widget.upperBgColor,
                    height: widget.waveDepth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: widget.upperContent,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
