// 列表操作事件
enum ListOperateType { insert, remove }

// 列表类型
enum ListType { messageList, chatList, categoryItemList, searchResultList }

// 抽象列表事件
abstract class ListEvent {}