import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class CategoryListOperate extends ListEvent {
  final int index;
  final ListOperateType type;
  final BaseInfoItem? item;
  final CategoryInfo? info;
  CategoryListOperate({
    required this.type,
    required this.index,
    this.item,
    this.info,
  });
}

class CategoryList {
  final RxList<CategoryInfo> _categoryList = <CategoryInfo>[].obs;
  RxList<CategoryInfo> get dataSource => _categoryList;
  // final RxMap<String, Queue<({String name, BaseInfoItem newItem})>>
  // _pendingMap = RxMap({}); 后续新增分类可能用到

  // 根据分类名称添加 指定分类区域 的元素
  bool addItem(String name, BaseInfoItem newItem) {
    try {
      CategoryInfo categoryInfo = _categoryList.firstWhere(
        (element) => element.name == name,
      );
      final exsitsIndex = categoryInfo.itemList.indexWhere(
        (item) => item.uid == newItem.uid,
      );
      if (exsitsIndex != -1) {
        // 当前元素已存在时 返回 
        return false;
      }
      categoryInfo.itemList.add(newItem);
      return true;
    } catch (e) {
      // debugPrint("发送了一个错误：$e 正在加入等待队列");
      // 存入 当前分类的 映射表 若当前 key 已存在则返回对应的 value
      // final queue = _pendingMap.putIfAbsent(name, () => Queue());
      // queue.add((name: name, newItem: newItem));
      return false;
    }
  }

  // 根据分类名称以及 uid 删除指定元素
  (int? itemIndex, BaseInfoItem? item) deleteItem(
    String name,
    String targetUid,
  ) {
    int categoryIndex = _categoryList.indexWhere(
      (element) => element.name == name,
    );
    if (categoryIndex == -1) {
      return (null, null);
    }
    int itemIndex = _categoryList[categoryIndex].itemList.indexWhere(
      (element) => element.uid == targetUid,
    );
    if (itemIndex == -1) {
      return (categoryIndex, null);
    }
    BaseInfoItem item = _categoryList[categoryIndex].itemList.removeAt(
      itemIndex,
    );
    return (itemIndex, item);
  }

  // 添加自定义名称的分类
  bool addCategory(CategoryInfo info) {
    final existIndex = _categoryList.indexWhere(
      (element) => element.name == info.name,
    );
    // 若该名称已存在则返回 false
    if (existIndex != -1) {
      return false;
    }
    _categoryList.add(info);

    // // 查询当前分类是否有滞留的元素未进入队列
    // final queue = _pendingMap.remove(info.name);
    // if (queue != null && queue.isNotEmpty) {
    //   while (queue.isNotEmpty) {
    //     final record = queue.removeFirst();
    //     // 正在等待重新添加
    //     final ok = addItem(record.name, record.newItem);
    //     if (!ok) {
    //       _pendingMap.putIfAbsent(info.name, () => Queue()).addFirst(record);
    //       break;
    //     }
    //   }
    // }
    return true;
  }

  // 根据指定名称删除
  bool deleteCategory(String name) {
    final existIndex = _categoryList.indexWhere(
      (element) => element.name == name,
    );
    if (existIndex == -1) return false;
    _categoryList.removeAt(existIndex);
    // _pendingMap.remove(name);
    return true;
  }

  void clear() {
    _categoryList.clear();
    // _pendingMap.clear();
  }
}
