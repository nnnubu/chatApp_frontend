import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/widgets/message/item_info/category_list/category_item_info.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/message_handler/base_handler.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class CategoryPullHandler extends BaseMessageHanlder {
  @override
  Future<MessageBusEvent?> handle(MessageDto dto) async {
    final Map<String, dynamic>? data = dto.data;
    if (data == null) return null;

    final String catName = data["CategoryName"];  // 哪个分类
    final int catType = data["CategoryType"]; // 系统自带 还是 用户自定义
    final int sort = data["sort"] ?? 0; // 权重 后续做权重排列可能用
    final bool isPullMoreItem = data["isPullMoreItem"] ?? false; // 是否加载更多

    // 初始加载时 指定 page 和 pageSize 为固定值
    // 后续处理的事件 根据 UI 层传递的 isPullMoreItem 来判定
    // 进入 监听时 根据 isPullMoreItem 来取 数据源中的 数据 而非此处传递的快照
    final categoryInfo = CategoryInfo(
      name: catName,
      type: catType,
      sort: sort,
      itemList: <CategoryItem>[].obs,
      page: 1,
      pageSize: 10,
      isPullMoreItem: isPullMoreItem,
    );
    return CategoryListEvent(info: categoryInfo);
  }

  @override
  MessageType supportType() {
    return MessageType.pullCategory;
  }
}