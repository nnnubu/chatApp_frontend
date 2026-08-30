import 'dart:async';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

// 使用 命名 Record 构造数据包
// typedef 为该 命名 Record 别名为 EventMatchResult
typedef EventMatchResult<T extends ListEvent> = ({
  bool matched,
  int index,
  ListOperateType operateType, 
  Object item,
});

class CommonAnimatedList extends StatefulWidget {
  final ListType type; // 列表类型
  final MessageController messageController; // 父组件传递控制器
  final ThemeController themeController;
  // 依赖以上两个字段获取订阅监听

  final EventMatchResult? Function(ListEvent event)
  eventPaser; // 父组件判断 推送事件 是否为自己需要的
  final Widget Function(dynamic item, Animation<double> animation)
  insertItemBuilder; // 父组件自行构造入队列表元素动画
  final Widget Function(dynamic item, Animation<double> animation)
  deleteItemBuilder; // 父组件自行构造出队列表元素动画
  final List<dynamic> dataSource; // 父组件自行提供数据源
  final VoidCallback? onPlayAnimation; // 父组件自行定义动画播放前的事件
  final Axis scrollDirection; // 滑动方向
  final bool Function()? shouldAutoScrollBottom; // 是否滑动到底部
  final ScrollController? scrollController; // 外部传入的滚动控制器，用于监听滚动位置
  final EdgeInsetsGeometry? padding; // 列表内边距

  const CommonAnimatedList({
    super.key,
    required this.type,
    required this.eventPaser,
    required this.insertItemBuilder,
    required this.deleteItemBuilder,
    required this.messageController,
    required this.themeController,
    required this.dataSource,
    required this.scrollDirection,
    this.onPlayAnimation,
    this.shouldAutoScrollBottom,
    this.scrollController,
    this.padding,
  });
  @override
  State<StatefulWidget> createState() {
    return _CommonAnimatedListState();
  }
}

class _CommonAnimatedListState extends State<CommonAnimatedList> {
  // GlobalKey：全局唯一标识，用于获取 AnimatedListState 内部动画控制器
  // 页面重建时，若旧 State 已销毁，同 Key 会创建全新 State，无法复用已销毁的动画状态
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  StreamSubscription<ListEvent>? _streamSub;
  ScrollController? _internalScrollController;
  // 事件缓存：_listKey 未就绪时暂存，build 完成后批量处理
  final List<EventMatchResult<ListEvent>> _pendingEvents = [];
  bool get _usesExternalController => widget.scrollController != null;
  ScrollController get _scrollController =>
      widget.scrollController ?? _internalScrollController!;

  @override
  void initState() {
    super.initState();
    if (!_usesExternalController) {
      _internalScrollController = ScrollController();
    }
    // 之前这里写了个数据源为空就返回直接不订阅的代码
    // 这是不对的，数据源为空也要订阅，否则数据增加的时候就会出现没有动画的情况
    _streamSub = widget.messageController.operateStream.listen((ListEvent event) {
      final EventMatchResult? parseResult = widget.eventPaser(event);
      // 但是这里需要注意 对于会话类消息来说，其他会话发送的消息可能会影响到当前会话，因为它照样会解析其他会话的消息来播放动画，因此需要外层手动管控 eventPaser 返回空值以隔离其他会话的影响

      // 数据包为空 或是 不匹配则返回
      if (parseResult == null || !parseResult.matched) return;
      //页面未挂载直接返回
      if (!mounted) return;
      // 列表未初始化时缓存事件，等 build 完成后处理
      if (_listKey.currentState == null) {
        _pendingEvents.add(parseResult);
        _scheduleFlush();
        return;
      }
      _handleEvent(parseResult);
    });
  }

  void _handleEvent(EventMatchResult<ListEvent> parseResult) {
    final operateType = parseResult.operateType;
    final index = parseResult.index;
    final item = parseResult.item;
    if (_listKey.currentState == null) return;
    switch (operateType) {
        // 通过 _listKey.currentState 获取列表内部控制器，执行带动画的删除函数
        // ?. 空安全调用，防止页面还没有 build 完成就操作
        case ListOperateType.insert:
          widget.onPlayAnimation?.call();
          _listKey.currentState!.insertItem(
            index,
            duration: const Duration(milliseconds: 300),
          );
          // 告诉被绑定的 AnimatedLsit 去 索引 index 下取数据

          // 自己发消息时滑动到最底下
          final needScroll = widget.shouldAutoScrollBottom?.call() ?? false;
          if (needScroll) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              final maxExtent = _scrollController.position.maxScrollExtent;
              final currentOffset = _scrollController.offset;
              final viewportHeight = _scrollController.position.viewportDimension;
              final scrollDistance = maxExtent - currentOffset;

              // 当滚动距离超过 1.5 屏时，先 jumpTo 到接近底部的位置，再做短距离动画
              // 避免长距离滚动时构建大量卡片导致卡顿
              if (scrollDistance > viewportHeight * 1.5) {
                // 先跳到距离底部一屏的位置
                final jumpTarget = (maxExtent - viewportHeight).clamp(0.0, maxExtent);
                _scrollController.jumpTo(jumpTarget);
                // 下一帧再做短距离动画到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scrollController.hasClients) return;
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                });
              } else {
                // 短距离直接动画
                _scrollController.animateTo(
                  maxExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          break;
        case ListOperateType.remove:
          _listKey.currentState!.removeItem(index, (context, animation) {
            return widget.deleteItemBuilder(item, animation);
          }, duration: const Duration(milliseconds: 300));
          // 告诉被绑定的 AnimatedList 删除自身 index 下的数据
          break;
      }
  }

  /// 调度一次缓存事件刷新（持续轮询直到列表就绪）
  void _scheduleFlush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_listKey.currentState != null && _pendingEvents.isNotEmpty) {
        _flushPendingEvents();
      } else if (_pendingEvents.isNotEmpty) {
        // 列表还没就绪，继续等下一帧
        _scheduleFlush();
      }
    });
  }

  /// 处理缓存的事件（_listKey 就绪后批量执行）
  void _flushPendingEvents() {
    if (_listKey.currentState == null || _pendingEvents.isEmpty) return;
    final events = List<EventMatchResult<ListEvent>>.from(_pendingEvents);
    _pendingEvents.clear();
    debugPrint('CommonAnimatedList 处理缓存事件 ${events.length} 条, type=${widget.type}');
    for (final e in events) {
      _handleEvent(e);
    }
  }

  @override
  void dispose() {
    // 取消流监听，防止内存泄漏
    _streamSub?.cancel();
    // 仅销毁内部创建的 ScrollController，外部传入的由外部管理
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 每次 build 后检查是否有缓存事件待处理
    _scheduleFlush();
    return Obx(() {
      final AppTheme t = widget.themeController.currentTheme;
      return Stack(
        children: [
          AnimatedList(
            // AnimatedList 会把组件的状态缓存在 index 上，删除某一个元素之后，后面的元素上移，就会继承在 index 的状态
            // 绑定全局 key，外部可以操控动画
            key: _listKey,
            initialItemCount: widget.dataSource.length,
            controller: _scrollController,
            scrollDirection: widget.scrollDirection,
            padding: widget.padding,
            itemBuilder: (context, index, animation) {
              // 防止相同事件类型的其他分类区域触发事件时 当前分类区域由于空数据源触发下面这个下标越界
              if (index < 0 || index >= widget.dataSource.length) {
                return const SizedBox.shrink();
              }
              // 此处的 index 即是 前面 insertItem 和 removeItem 里传输的 index
              final item = widget.dataSource[index];
              // 入场淡入动画 新增条目时播放 由父组件自行定义
              return widget.insertItemBuilder(item, animation);
            },
          ),
          if (widget.dataSource.isEmpty) Center(child: Text("暂无数据",style: TextStyle(
                        color:t.fontColor,
                      ),)),
        ],
      );
    });
  }
}
