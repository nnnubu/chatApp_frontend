import 'package:chatapp/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 文件顶层全局常量
const int minYear = 1900;
const double selectorItemHeight = 50;
const double selectorPanelHeight = 180;
const double titleFontSize = 22;
const double itemTextFontSize = 18;
const double gapTitleSelector = 30;
const double gapSelectorBtn = 30;
const double btnWidth = 200;
const double btnVertPadding = 16;
const double btnRadius = 12;
const double iconSize = 30;
const Duration jumpAnimDuration = Duration(milliseconds: 100);

class BirthdaySelector extends StatefulWidget {
  final String? initialBirthStr;
  final Color bgColor;
  final Color btnColor;
  final void Function(String birthStr) onConfirm;
  final void Function(bool visible) onVisible;

  const BirthdaySelector({
    super.key,
    this.initialBirthStr,
    this.bgColor = Colors.white,
    this.btnColor = Colors.white,
    required this.onConfirm,
    required this.onVisible,
  });

  @override
  State<BirthdaySelector> createState() => _BirthdaySelectorState();
}

class _BirthdaySelectorState extends State<BirthdaySelector>
    with SingleTickerProviderStateMixin {
  late final int maxYear;
  late int _selYear;
  late int _selMonth;
  late int _selDay;

  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  late TextEditingController _yTxtCtrl;
  late TextEditingController _mTxtCtrl;
  late TextEditingController _dTxtCtrl;

  bool _isWheelScrolling = false;

  DateTime? _parseDateStr(String dateStr) {
    final parts = dateStr.split("-");
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _formatDateToString(int y, int m, int d) {
    String month = m.toString().padLeft(2, "0");
    String day = d.toString().padLeft(2, "0");
    return "$y-$month-$day";
  }

  int _getMaxDay(int year, int month) {
    if (month == 2) {
      if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
        return 29;
      }
      return 28;
    }
    const List<int> bigMonth = [1, 3, 5, 7, 8, 10, 12];
    return bigMonth.contains(month) ? 31 : 30;
  }

  void _onYearChange(int idx) {
    _isWheelScrolling = true;
    final year = minYear + idx;
    _yTxtCtrl.text = year.toString();
    setState(() => _selYear = year);
    _fixDayRange();
    Future.delayed(const Duration(milliseconds: 150), () {
      _isWheelScrolling = false;
    });
  }

  void _onMonthChange(int idx) {
    _isWheelScrolling = true;
    final month = idx + 1;
    _mTxtCtrl.text = month.toString();
    setState(() => _selMonth = month);
    _fixDayRange();
    Future.delayed(const Duration(milliseconds: 150), () {
      _isWheelScrolling = false;
    });
  }

  void _onDayChange(int idx) {
    _isWheelScrolling = true;
    _dTxtCtrl.text = (idx + 1).toString();
    setState(() => _selDay = idx + 1);
    Future.delayed(const Duration(milliseconds: 150), () {
      _isWheelScrolling = false;
    });
  }

  void _fixDayRange() {
    final max = _getMaxDay(_selYear, _selMonth);
    if (_selDay > max) {
      setState(() => _selDay = max);
      _dayCtrl.animateToItem(
        max - 1,
        duration: jumpAnimDuration,
        curve: Curves.ease,
      );
    }
  }

  void _handleConfirm() {
    String birthResult = _formatDateToString(_selYear, _selMonth, _selDay);
    widget.onConfirm(birthResult);
    widget.onVisible(false);
  }

  @override
  void initState() {
    super.initState();
    maxYear = DateTime.now().year;

    DateTime? initDate;
    if (widget.initialBirthStr != null && widget.initialBirthStr!.isNotEmpty) {
      initDate = _parseDateStr(widget.initialBirthStr!);
    }
    initDate ??= DateTime(maxYear, 1, 1);
    _selYear = initDate.year;
    _selMonth = initDate.month;
    _selDay = initDate.day;

    _yearCtrl = FixedExtentScrollController(initialItem: _selYear - minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _selMonth - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _selDay - 1);

    _yTxtCtrl = TextEditingController(text: _selYear.toString());
    _mTxtCtrl = TextEditingController(text: _selMonth.toString());
    _dTxtCtrl = TextEditingController(text: _selDay.toString());
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yTxtCtrl.dispose();
    _mTxtCtrl.dispose();
    _dTxtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int yearItemCount = maxYear - minYear + 1;
    final int currentMaxDay = _getMaxDay(_selYear, _selMonth);
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: gapSelectorBtn),
                      Row(
                        children: [
                          // 年份滚轮
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: selectorPanelHeight,
                                  child: CupertinoPicker(
                                    scrollController: _yearCtrl,
                                    itemExtent: selectorItemHeight,
                                    onSelectedItemChanged: _onYearChange,
                                    children: List.generate(yearItemCount, (
                                      idx,
                                    ) {
                                      int y = minYear + idx;
                                      return Center(
                                        child: Text(
                                          "$y 年",
                                          style: TextStyle(
                                            fontSize: itemTextFontSize,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),

                                TextField(
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  controller: _yTxtCtrl,
                                  onChanged: (value) {
                                    if (value.isEmpty || _isWheelScrolling) {
                                      return;
                                    }
                                    int? num = int.tryParse(value);
                                    if (num == null) return;
                                    if (num > maxYear || num == 0) {
                                      _yTxtCtrl.text = maxYear.toString();
                                    }
                                    if (_yTxtCtrl.text.length == 4 ||
                                        _yearCtrl.hasClients) {
                                      _yearCtrl.jumpToItem(
                                        int.parse(_yTxtCtrl.text) - minYear,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          // 月份滚轮
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: selectorPanelHeight,
                                  child: CupertinoPicker(
                                    scrollController: _monthCtrl,
                                    itemExtent: selectorItemHeight,
                                    onSelectedItemChanged: _onMonthChange,
                                    children: List.generate(12, (idx) {
                                      int m = idx + 1;
                                      return Center(
                                        child: Text(
                                          "$m 月",
                                          style: TextStyle(
                                            fontSize: itemTextFontSize,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),

                                TextField(
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  controller: _mTxtCtrl,
                                  onChanged: (value) {
                                    if (value.isEmpty || _isWheelScrolling) {
                                      return;
                                    }
                                    int? num = int.tryParse(value);
                                    if (num == null) return;
                                    if (num > 12 || num == 0) {
                                      _mTxtCtrl.text = "12";
                                    }
                                    if (_monthCtrl.hasClients) {
                                      _monthCtrl.jumpToItem(
                                        int.parse(_mTxtCtrl.text) - 1,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          // 日期滚轮
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: selectorPanelHeight,
                                  child: CupertinoPicker(
                                    scrollController: _dayCtrl,
                                    itemExtent: selectorItemHeight,
                                    onSelectedItemChanged: _onDayChange,
                                    children: List.generate(currentMaxDay, (
                                      idx,
                                    ) {
                                      int d = idx + 1;
                                      return Center(
                                        child: Text(
                                          "$d 日",
                                          style: TextStyle(
                                            fontSize: itemTextFontSize,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                TextField(
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  controller: _dTxtCtrl,
                                  onChanged: (value) {
                                    if (value.isEmpty || _isWheelScrolling) {
                                      return;
                                    }
                                    int? num = int.tryParse(value);
                                    if (num == null) return;
                                    if (num > currentMaxDay || num == 0) {
                                      _dTxtCtrl.text = _getMaxDay(
                                        _selYear,
                                        _selDay,
                                      ).toString();
                                    }
                                    if (_dayCtrl.hasClients) {
                                      _dayCtrl.jumpToItem(
                                        int.parse(_dTxtCtrl.text) - 1,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: gapSelectorBtn),

                      SizedBox(
                        width: btnWidth,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: btnVertPadding,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(btnRadius),
                            ),
                            backgroundColor: widget.btnColor
                          ),
                          onPressed: _handleConfirm,
                          child: const Text(
                            "确定",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
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
