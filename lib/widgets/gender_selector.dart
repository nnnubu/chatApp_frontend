import 'package:chatapp/constants/app_constants.dart';
import 'package:flutter/material.dart';

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
  final Map<int, IconData> _iconMap = {
    0: Icons.lock_outline,
    1: Icons.female,
    2: Icons.male,
  };

  late final Map<int, AnimationController> _ctrlPool;
  late final Map<int, Animation<double>> _scalePool;
  int? _curSelect;

  void onTapItem(int index) {
    if (_curSelect == index) return;
    setState(() {
      if (_curSelect != null) {
        _ctrlPool[_curSelect]!.reverse();
      }
      _curSelect = index;
      _ctrlPool[index]!.forward(from: 0);
    });
  }

  @override
  void initState() {
    super.initState();
    _curSelect = widget.initSelect;
    _ctrlPool = {};
    _scalePool = {};
    for (int idx = 0; idx < widget.genderMap.length; idx++) {
      final ctrl = AnimationController(vsync: this, duration: animDuration);
      _ctrlPool[idx] = ctrl;
      _scalePool[idx] = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }
    if (_curSelect != null && _curSelect! < widget.genderMap.length) {
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
          Positioned.fill(
            child: GestureDetector(
              onTap: () => widget.onVisible(false),
              child: ColoredBox(color: Colors.black54),
            ),
          ),
          Center(
            child: Container(
              width: screenWidth * AppBase.popBoxWidthRatio,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    "选择性别",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.btnColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 选项卡片
                  Row(
                    children: List.generate(widget.genderMap.length, (int index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: index == 1 ? 8 : 0,
                          ),
                          child: _buildGenderCard(index),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // 按钮行
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onVisible(false),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                "取消",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_curSelect != null) {
                              widget.onSelect(_curSelect!);
                            }
                            widget.onVisible(false);
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.btnColor,
                                  widget.btnColor.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.btnColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "确定",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard(int index) {
    final isSelected = _curSelect == index;
    return AnimatedBuilder(
      animation: _scalePool[index]!,
      builder: (context, child) {
        return Transform.scale(
          scale: _scalePool[index]!.value,
          child: GestureDetector(
            onTap: () => onTapItem(index),
            child: AnimatedContainer(
              duration: animDuration,
              height: 100,
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.btnColor.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? widget.btnColor : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconMap[index] ?? Icons.person,
                    size: 32,
                    color: isSelected ? widget.btnColor : Colors.grey.shade500,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${widget.genderMap[index]}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? widget.btnColor : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
