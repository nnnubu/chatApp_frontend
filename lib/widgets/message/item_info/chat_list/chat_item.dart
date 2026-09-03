import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/ws/ack_helper.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

// 此组件共用于 MessageList 以及 ChatList
class ChatItem extends BaseInfoItem {
  String? content;
  // 消息内容类型 0=文本 1=图片 2=语音 3=视频
  int contentType = 0;
  // 本地图片路径：图片消息乐观渲染阶段（上传完成前）用于展示本地选图
  String? localImagePath;
  // 本地语音路径：语音消息上传失败时保留临时文件，供重发时重新上传
  String? localVoicePath;
  // 本地语音时长（秒）：重发重新上传时需要
  int localVoiceDuration = 0;
  // 内容版本号：图片上传完成后更新 content 时自增，触发气泡从本地图切换到网络图
  final RxInt contentVersion = 0.obs;
  final RxInt unReadCount;
  final String? msgId; // 后端推送给前端必带以下 4 条字段
  final String? senderUid; // 消息发送方
  final String? receiverUid; // 消息接收方
  final String? conversationUid; // 隶属会话标识
  bool isInsertToTop; // 是否插入队首
  String? requestId; // 前端发送时生成，用于 ACK 追踪（重发时会更新）
  final Rx<AckStatus> sendStatus; // 消息发送状态

  ChatItem({
    required super.uid,
    required super.nickname,
    required super.avatarUrl,
    this.msgId,
    this.senderUid,
    this.receiverUid,
    this.conversationUid,
    this.content,
    this.contentType = 0,
    this.localImagePath,
    this.localVoicePath,
    this.localVoiceDuration = 0,
    this.isInsertToTop = false,
    this.requestId,
    AckStatus sendStatus = AckStatus.success,
    int unReadCount = 1,
  })  : unReadCount = unReadCount.obs,
        sendStatus = sendStatus.obs;
}
