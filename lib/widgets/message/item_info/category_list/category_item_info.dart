import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class CategoryItem extends BaseInfoItem {
  final bool isOnline;
  CategoryItem({
    required super.uid,
    required super.nickname,
    required super.avatarUrl,
    this.isOnline = false,
  });
}

class CategoryInfo {
  final String name; // 自定义分类名
  final int type; // 该分类的类型 1：系统内置好友 2：系统内置群聊 3：用户自定义
  final int sort; // 排序权重
  final RxList<BaseInfoItem> itemList; // 分类内部元素
  int page; // 页码
  final int pageSize; // 每页个数
  final bool isPullMoreItem; // 是否获取更多分页数据
  bool? hasMore; // 是否还有更多数据
  CategoryInfo({
    required this.name,
    required this.type,
    required this.sort,
    required this.itemList,
    required this.page,
    required this.pageSize,
    required this.isPullMoreItem,
    this.hasMore
  });
}
