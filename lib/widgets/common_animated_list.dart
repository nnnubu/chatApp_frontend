import 'dart:async';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
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
  final MessageController controller; // 父组件传递控制器

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

  const CommonAnimatedList({
    super.key,
    required this.type,
    required this.eventPaser,
    required this.insertItemBuilder,
    required this.deleteItemBuilder,
    required this.controller,
    required this.dataSource,
    required this.scrollDirection,
    this.onPlayAnimation,
    this.shouldAutoScrollBottom,
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 之前这里写了个数据源为空就返回直接不订阅的代码
    // 这是不对的，数据源为空也要订阅，否则数据增加的时候就会出现没有动画的情况
    _streamSub = widget.controller.operateStream.listen((ListEvent event) {
      final EventMatchResult? parseResult = widget.eventPaser(event);

      // 数据包为空 或是 不匹配则返回
      if (parseResult == null || !parseResult.matched) return;
      // 解构 命名 Record 数据包中的各个数据并为其命名
      final (:operateType, :index, :item, :matched) = parseResult;
      //页面未挂载、列表未初始化直接返回
      if (!mounted || _listKey.currentState == null) return;
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
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
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
    });
  }

  @override
  void dispose() {
    // 取消流监听，防止内存泄漏
    _streamSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Stack(
        children: [
          AnimatedList(
            // AnimatedList 会把组件的状态缓存在 index 上，删除某一个元素之后，后面的元素上移，就会继承在 index 的状态
            // 绑定全局 key，外部可以操控动画
            key: _listKey,
            initialItemCount: widget.dataSource.length,
            controller: _scrollController,
            scrollDirection: widget.scrollDirection,
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
          if (widget.dataSource.isEmpty) const Center(child: Text("暂无数据")),
        ],
      );
    });
  }
}
