import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

enum FriendOperateIdentity {
  receiver, // 我是接收人：显示同意/拒绝按钮
  applicant, // 我是申请人：只显示“等待对方处理”，无操作按钮
}

class FriendApplyMessageItem extends BaseInfoItem {
  final String msgId; // 当前好友请求唯一 ID
  final String applyUid; // 发起者 ID
  final String targetUid; // 接收者 ID
  final String lastContent;
  final int status;
  late final RxInt unReadCount;
  late final Rx<MessageType> type;

  FriendApplyMessageItem({
    required super.uid,
    required super.nickname,
    required super.avatarUrl,
    required this.msgId,
    required this.applyUid,
    required this.targetUid,
    required this.lastContent,
    required this.status,
    required this.unReadCount,
    required MessageType typeVal,
  }) {
    type = typeVal.obs;
  }

  MessageType get typeVal => type.value;

  // 判断当前登录用户是申请人还是接收人
  FriendOperateIdentity getIdentity(String currentUid) {
    if (currentUid == applyUid) {
      return FriendOperateIdentity.applicant;
    } else {
      return FriendOperateIdentity.receiver;
    }
  }
}
