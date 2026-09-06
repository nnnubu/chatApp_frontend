import 'dart:async';

import 'package:chatapp/api/user_api.dart';
import 'package:chatapp/constants/app_constants.dart';
import 'package:chatapp/controller/global/messageController/chatList/chat_list.dart';
import 'package:chatapp/controller/global/theme_controller.dart';
import 'package:chatapp/controller/global/messageController/base.dart';
import 'package:chatapp/controller/global/messageController/message_controller.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:chatapp/dto/dto_message.dart';
import 'package:chatapp/service/user_service.dart';
import 'package:chatapp/utils/request_id_generator.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/chat_item_card.dart';
import 'package:chatapp/widgets/common_animated_list.dart';
import 'package:chatapp/widgets/message/item_info/base_info.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/chat_item.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/image_message.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/video_message.dart';
import 'package:chatapp/ws/ack_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:chatapp/ws/message_dispatcher.dart';
import 'package:chatapp/ws/websocket_service.dart';
import 'package:chatapp/widgets/message/item_info/chat_list/voice_message.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() {
    return _ChatPageState();
  }
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late BaseInfoItem? _info;
  late ChatItem _chatItem; // 最新消息的快照 用于简便获取会话的基础信息
  late MessageController _messageController;
  late ConversationState _conversationState;
  late ThemeController themeController;
  late UserController userController;
  final TextEditingController _textEditingController = TextEditingController();
  late RxList<ChatItem> dataSource;
  bool _isArgumentLegal = false;
  bool _isLoadingHistory = false;
  bool _shouldScrollToBottom = false;
  // 消息列表滚动控制：用于监听是否在底部
  late ScrollController _scrollController;
  // 用户是否在列表底部（接近最底部）
  bool _atBottom = true;
  // 未滑到底时，对方发来的新消息条数（显示回到底部按钮角标）。
  // 由 MessageController 在"挂起对方消息"时维护。
  RxDouble loadHistoryBox = 0.0.obs;
  StreamSubscription? _ackSub;

  // ===== 语音消息字段 =====
  bool _isVoiceMode = false; // 是否语音输入模式
  bool _isRecording = false; // 是否正在录音
  bool _cancelRecording = false; // 是否上滑取消
  int _recordSeconds = 0; // 录音时长（秒）
  String? _recordPath; // 录音文件路径
  AudioRecorder? _recorder;
  Timer? _recordTimer;
  // 录音浮动层显示状态
  final RxBool _showRecordOverlay = false.obs;

  Future<void> _clearUnRead() async {
    UserService.markReadStatus(_chatItem.conversationUid!);
    // 使用 WidgetsBinding.instance.addPostFrameCallback 将操作注册到全局调度器 SchedulerBinding 脱离当前 State 组件树 这样就不会触发 在渲染期间触发重新渲染标记 导致 flutter 报错
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageController.messageList.clearUnReadCount(
        _chatItem.conversationUid!,
      );
    });
  }

  /// 根据 requestId 更新乐观渲染消息的发送状态
  void _updateMessageStatus(String requestId, AckStatus status) {
    for (int i = 0; i < dataSource.length; i++) {
      if (dataSource[i] is ChatItem && dataSource[i].requestId == requestId) {
        final ChatItem item = dataSource[i];
        item.sendStatus.value = status;
        break;
      }
    }
  }

  /// 乐观渲染发送消息：先插入本地临时消息，再发送
  void _sendMessageOptimistic(String content, {int contentType = 0}) {
    final String requestId = RequestIdGenerator.generate();
    final ChatItem tempMsg = ChatItem(
      uid: userController.uid,
      nickname: userController.userInfo.value?.nickname ?? '我',
      avatarUrl: userController.avatar.url,
      content: content,
      contentType: contentType,
      senderUid: userController.uid,
      receiverUid: _chatItem.uid,
      conversationUid: _chatItem.conversationUid,
      requestId: requestId,
      sendStatus: AckStatus.pending,
    );
    // 通过 messageController 插入，触发去重和 CommonAnimatedList 动画
    _messageController.addChatItem(tempMsg, dataSource.length);
    _shouldScrollToBottom = true;
    // 发送消息
    WebSocketService.instance.sendDto(
      MessageDto(
        msgType: MessageType.chat,
        requestId: requestId,
        data: {
          "conversationUid": _chatItem.conversationUid,
          "receiverUid": _chatItem.uid,
          "contentType": contentType,
          "content": content,
        },
      ),
    );
  }

  /// 发送图片消息：先乐观渲染（本地图+转圈）-> 上传 -> 成功填URL发WS / 失败标记感叹号
  /// 发送图片消息：选图 -> [resendItem] 重发复用本地图，否则打开相册单选
  Future<void> _sendImageMessage({ChatItem? resendItem}) async {
    XFile? picked;
    if (resendItem != null && resendItem.localImagePath != null) {
      // 重发：直接使用本地已选图片
      picked = XFile(resendItem.localImagePath!);
    } else {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    }
    if (picked == null) return;
    await _sendImageFile(picked, resendItem: resendItem);
  }

  /// 发送单张图片文件（乐观渲染 -> 上传 -> 回填URL -> 发WS）
  /// 供相册单选/多选/重发复用；[resendItem] 非空表示重发该消息
  Future<void> _sendImageFile(XFile picked, {ChatItem? resendItem}) async {
    // 当前图片消息的 requestId，供 catch 分支标记失败状态
    String? pendingRequestId;
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';

      // 1. 先插入乐观消息（pending 转圈 + 本地图）
      final String requestId =
          resendItem?.requestId ?? RequestIdGenerator.generate();
      pendingRequestId = requestId;
      final ChatItem tempMsg = ChatItem(
        uid: userController.uid,
        nickname: userController.userInfo.value?.nickname ?? '我',
        avatarUrl: userController.avatar.url,
        content: resendItem?.content, // 重发时可能已有 content
        contentType: ContentType.image.code,
        localImagePath: picked.path,
        senderUid: userController.uid,
        receiverUid: _chatItem.uid,
        conversationUid: _chatItem.conversationUid,
        requestId: requestId,
        sendStatus: AckStatus.pending,
      );
      if (resendItem == null) {
        // 新消息：插入数据源触发动画
        _messageController.addChatItem(tempMsg, dataSource.length);
        _shouldScrollToBottom = true;
      } else {
        // 重发：更新已有消息状态为 pending
        resendItem.sendStatus.value = AckStatus.pending;
        resendItem.localImagePath = picked.path;
      }

      // 2. 上传图片
      final resp = await UserApi.uploadChatImage(bytes, ext);
      // 注意：DioUtil 拦截器已剥离 code/message，resp 直接就是 data 对象
      if (resp == null) {
        debugPrint('图片上传失败: 返回为空');
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      final originUrl = resp['originUrl'] as String?;
      final thumbUrl = resp['thumbUrl'] as String?;
      final width = (resp['width'] as num?)?.toInt() ?? 0;
      final height = (resp['height'] as num?)?.toInt() ?? 0;
      if (originUrl == null || originUrl.isEmpty) {
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      // 3. 组装图片消息 content JSON 并更新乐观消息
      final contentJson = ImageMessageContent.build(
        originUrl,
        thumbUrl ?? originUrl,
        width,
        height,
      );
      _updateMessageContent(requestId, contentJson);
      // 4. 发送 WS
      WebSocketService.instance.sendDto(
        MessageDto(
          msgType: MessageType.chat,
          requestId: requestId,
          data: {
            "conversationUid": _chatItem.conversationUid,
            "receiverUid": _chatItem.uid,
            "contentType": ContentType.image.code,
            "content": contentJson,
          },
        ),
      );
    } catch (e) {
      debugPrint('发送图片异常: $e');
      // 上传/读取失败：标记为 roamed（感叹号）供用户点击重试
      if (pendingRequestId != null) {
        _updateMessageStatus(pendingRequestId!, AckStatus.roamed);
      }
      showTipSnackbar(msg: '图片发送失败，请重试', isSuccess: false);
    }
  }

  /// 根据 requestId 更新乐观消息的 content（图片/语音/视频上传完成后切换为网络内容）
  void _updateMessageContent(String requestId, String content) {
    for (int i = 0; i < dataSource.length; i++) {
      if (dataSource[i] is ChatItem && dataSource[i].requestId == requestId) {
        final ChatItem item = dataSource[i];
        item.content = content;
        item.localImagePath = null; // 清除本地路径，后续渲染走网络图
        item.localVoicePath = null; // 语音上传成功后本地临时文件已清理，走网络播放
        item.localVideoPath = null; // 视频上传成功后本地临时文件已清理，走网络播放
        item.contentVersion.value++; // 触发气泡重建
        break;
      }
    }
  }

  // ==================== 视频消息 ====================

  /// 发送视频消息：选视频 -> [resendItem] 重发复用本地视频，否则打开相册单选
  Future<void> _sendVideoMessage({ChatItem? resendItem}) async {
    XFile? picked;
    if (resendItem != null && resendItem.localVideoPath != null) {
      // 重发：直接使用本地已选视频
      picked = XFile(resendItem.localVideoPath!);
    } else {
      picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
    }
    if (picked == null) return;
    await _sendVideoFile(picked, resendItem: resendItem);
  }

  /// 发送单个视频文件（乐观渲染 -> 上传 -> 回填URL -> 发WS）
  /// 供相册单选/多选/重发复用；[resendItem] 非空表示重发该消息
  Future<void> _sendVideoFile(XFile picked, {ChatItem? resendItem}) async {
    String? pendingRequestId;
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'mp4';

      // 1. 先插入乐观消息（pending 转圈 + 本地视频占位）
      final String requestId =
          resendItem?.requestId ?? RequestIdGenerator.generate();
      pendingRequestId = requestId;
      final ChatItem tempMsg = ChatItem(
        uid: userController.uid,
        nickname: userController.userInfo.value?.nickname ?? '我',
        avatarUrl: userController.avatar.url,
        content: resendItem?.content, // 重发时可能已有 content
        contentType: ContentType.video.code,
        localVideoPath: picked.path,
        senderUid: userController.uid,
        receiverUid: _chatItem.uid,
        conversationUid: _chatItem.conversationUid,
        requestId: requestId,
        sendStatus: AckStatus.pending,
      );
      if (resendItem == null) {
        // 新消息：插入数据源触发动画
        _messageController.addChatItem(tempMsg, dataSource.length);
        _shouldScrollToBottom = true;
      } else {
        // 重发：更新已有消息状态为 pending
        resendItem.sendStatus.value = AckStatus.pending;
        resendItem.localVideoPath = picked.path;
      }

      // 2. 上传视频
      final resp = await UserApi.uploadChatVideo(bytes, ext);
      // 注意：DioUtil 拦截器已剥离 code/message，resp 直接就是 data 对象
      if (resp == null) {
        debugPrint('视频上传失败: 返回为空');
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      final url = resp['url'] as String?;
      if (url == null || url.isEmpty) {
        debugPrint('视频上传失败: url 为空');
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      // 3. 组装视频消息 content JSON 并更新乐观消息
      final contentJson = VideoMessageContent.build(url);
      _updateMessageContent(requestId, contentJson);
      // 4. 发送 WS
      WebSocketService.instance.sendDto(
        MessageDto(
          msgType: MessageType.chat,
          requestId: requestId,
          data: {
            "conversationUid": _chatItem.conversationUid,
            "receiverUid": _chatItem.uid,
            "contentType": ContentType.video.code,
            "content": contentJson,
          },
        ),
      );
    } catch (e) {
      debugPrint('发送视频异常: $e');
      // 上传/读取失败：标记为 roamed（感叹号）供用户点击重试
      if (pendingRequestId != null) {
        _updateMessageStatus(pendingRequestId!, AckStatus.roamed);
      }
      showTipSnackbar(msg: '视频发送失败，请重试', isSuccess: false);
    }
  }

  /// 打开相册多选（图片+视频混合，最多9个），选完逐个发送
  Future<void> _pickAndSendMedia() async {
    try {
      final AppTheme t = Get.find<ThemeController>().currentTheme;
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: 9,
          requestType: RequestType.common, // 图片 + 视频 混合选择
          gridCount: 4,
          themeColor: t.primaryColor,
          // 显式中文文本委托：自绘选择器界面（标题/按钮/提示）显示中文
          textDelegate: const AssetPickerTextDelegate(),
        ),
      );
      if (assets == null || assets.isEmpty) return;
      // 依次发送：图片走图片链路，视频走视频链路（各自独立乐观渲染+上传）
      // 注意：photo_manager 对视频的 asset.file 可能复用同一缓存文件路径，
      // 必须立即复制到独立临时文件，否则多个视频会被覆盖成同一份内容
      final Directory tempDir = await getTemporaryDirectory();
      for (final AssetEntity asset in assets) {
        final File? file = await asset.file;
        if (file == null) continue;
        final String rawName = file.path.split(Platform.pathSeparator).last;
        final String ext = rawName.contains('.')
            ? '.${rawName.split('.').last}'
            : (asset.type == AssetType.video ? '.mp4' : '.jpg');
        final File copied = File(
          '${tempDir.path}/chat_media_${asset.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
        await file.copy(copied.path);
        final XFile xf = XFile(
          copied.path,
          name: copied.path.split(Platform.pathSeparator).last,
        );
        if (asset.type == AssetType.image) {
          await _sendImageFile(xf);
        } else if (asset.type == AssetType.video) {
          await _sendVideoFile(xf);
        }
      }
    } catch (e) {
      debugPrint('打开相册多选异常: $e');
      showTipSnackbar(msg: '打开相册失败', isSuccess: false);
    }
  }

  // ==================== 语音消息 ====================

  /// 切换 文本/语音 输入模式
  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });
    if (_isVoiceMode) {
      FocusScope.of(context).unfocus();
    }
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      _recorder ??= AudioRecorder();
      final bool hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        showTipSnackbar(msg: '需要麦克风权限才能录音', isSuccess: false);
        return;
      }
      // 生成临时录音文件路径
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _cancelRecording = false;
        _recordSeconds = 0;
        _recordPath = path;
      });
      _showRecordOverlay.value = true;
      // 启动计时器
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      debugPrint('开始录音失败: $e');
      _showRecordOverlay.value = false;
      _isRecording = false;
      showTipSnackbar(msg: '录音失败，请重试', isSuccess: false);
    }
  }

  /// 停止录音并发送
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _showRecordOverlay.value = false;
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (e) {
      debugPrint('停止录音异常: $e');
    }
    setState(() => _isRecording = false);
    if (_cancelRecording || path == null) {
      // 上滑取消 或 无有效文件
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      return;
    }
    // 太短的录音（<1秒）提示取消
    if (_recordSeconds < 1) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
      showTipSnackbar(msg: '说话时间太短', isSuccess: false);
      return;
    }
    await _sendVoiceMessage(path, _recordSeconds);
  }

  /// 取消录音（上滑时调用）
  Future<void> _doCancelRecording() async {
    _cancelRecording = true;
    _recordTimer?.cancel();
    _showRecordOverlay.value = false;
    try {
      await _recorder?.cancel();
    } catch (e) {
      debugPrint('取消录音异常: $e');
    }
    setState(() => _isRecording = false);
  }

  /// 构建"按住说话"按钮
  Widget _buildHoldToTalkButton(AppTheme t) {
    return GestureDetector(
      // 长按触发录音
      onLongPressStart: (_) {
        _startRecording();
      },
      // 移动过程中检测上滑取消
      onLongPressMoveUpdate: (details) {
        // 手指向上滑出按钮上方一定距离视为取消
        final bool movedUp = details.localPosition.dy < -60;
        if (movedUp != _cancelRecording) {
          setState(() => _cancelRecording = movedUp);
        }
      },
      // 松开手指结束
      onLongPressEnd: (_) {
        if (_cancelRecording) {
          _doCancelRecording();
        } else {
          _stopRecordingAndSend();
        }
      },
      onLongPressCancel: () {
        _doCancelRecording();
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 7, 0),
        decoration: BoxDecoration(
          color: _isRecording
              ? (_cancelRecording
                    ? Colors.red.shade100
                    : t.primaryColor.withOpacity(0.15))
              : t.thirdColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: _isRecording
              ? (_cancelRecording
                    ? const Text(
                        "松开取消",
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RecordingWave(color: t.primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            "松开发送",
                            style: TextStyle(fontSize: 16, color: t.fontColor),
                          ),
                        ],
                      ))
              : Text(
                  "按住 说话",
                  style: TextStyle(fontSize: 16, color: t.fontColor),
                ),
        ),
      ),
    );
  }

  /// 录音浮动层：仅上滑取消时显示"松开取消"提示
  /// （录音中的状态通过按住说话按钮内的音柱动画体现，顶部不再显示计时）
  Widget _buildRecordOverlay(AppTheme t) {
    return Obx(() {
      // 录音中不显示顶部提示；只有上滑取消时才显示
      if (!_showRecordOverlay.value || !_cancelRecording) {
        return const SizedBox.shrink();
      }
      return Positioned(
        top: 20,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "松开取消",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// 发送语音消息：先上传成功 -> 再插入列表（带完整 content）-> 发 WS
  /// 发送语音消息：乐观渲染 -> 上传 -> 回填URL -> 发WS
  /// 断网/上传失败时消息仍保留在列表（显示感叹号 + 本地可试听），
  /// 由用户点击感叹号重发或长按删除，保证发送状态可见。
  /// [resendItem] 非空表示重发：复用原 requestId 与本地语音文件，重新上传并发送
  Future<void> _sendVoiceMessage(
    String path,
    int seconds, {
    ChatItem? resendItem,
  }) async {
    String? pendingRequestId;
    bool needDelete = false; // 仅成功发送后才清理本地临时文件
    try {
      final bytes = await File(path).readAsBytes();
      final requestId = resendItem?.requestId ?? RequestIdGenerator.generate();
      pendingRequestId = requestId;

      // 1. 乐观插入语音消息（pending 转圈 + 本地可试听占位气泡）
      //    重发时复用已有 item（保留 requestId），不重复插入
      if (resendItem == null) {
        final ChatItem tempMsg = ChatItem(
          uid: userController.uid,
          nickname: userController.userInfo.value?.nickname ?? '我',
          avatarUrl: userController.avatar.url,
          content: '',
          contentType: ContentType.voice.code,
          localVoicePath: path,
          localVoiceDuration: seconds,
          senderUid: userController.uid,
          receiverUid: _chatItem.uid,
          conversationUid: _chatItem.conversationUid,
          requestId: requestId,
          sendStatus: AckStatus.pending,
        );
        _messageController.addChatItem(tempMsg, dataSource.length);
        _shouldScrollToBottom = true;
      } else {
        // 重发：复用原 item，恢复本地语音路径并回到 pending
        resendItem.localVoicePath = path;
        resendItem.sendStatus.value = AckStatus.pending;
      }

      // 2. 上传语音
      final resp = await UserApi.uploadChatVoice(bytes, 'm4a');
      if (resp == null) {
        debugPrint('语音上传失败: 返回为空');
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      final url = resp['url'] as String?;
      if (url == null || url.isEmpty) {
        debugPrint('语音上传失败: url 为空');
        _updateMessageStatus(requestId, AckStatus.roamed);
        return;
      }
      // 3. 回填 content
      final contentJson = VoiceMessageContent.build(url, seconds.toDouble());
      _updateMessageContent(requestId, contentJson);
      // 上传成功 -> 本地临时文件可清理
      needDelete = true;
      // 4. 发送 WS
      WebSocketService.instance.sendDto(
        MessageDto(
          msgType: MessageType.chat,
          requestId: requestId,
          data: {
            "conversationUid": _chatItem.conversationUid,
            "receiverUid": _chatItem.uid,
            "contentType": ContentType.voice.code,
            "content": contentJson,
          },
        ),
      );
    } catch (e) {
      debugPrint('发送语音异常: $e');
      if (pendingRequestId != null) {
        _updateMessageStatus(pendingRequestId!, AckStatus.roamed);
      }
      showTipSnackbar(msg: '语音发送失败，请重试', isSuccess: false);
    } finally {
      // 仅成功发送后清理临时文件；失败时保留本地文件，供用户点击感叹号重新上传
      if (needDelete) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  /// 手动重新发送失败的消息
  void _resendMessage(ChatItem item) {
    if (item.requestId == null) return;
    debugPrint(
      "重发消息 requestId=${item.requestId} 当前状态=${item.sendStatus.value}",
    );
    // 图片消息且 content 不是有效图片JSON（说明上传阶段失败，仅本地图）：重新走上传流程
    if (item.contentType == ContentType.image.code &&
        ImageMessageContent.tryParse(item.content) == null) {
      debugPrint("图片消息上传阶段失败，触发重新上传");
      _sendImageMessage(resendItem: item);
      return;
    }
    // 视频消息：content 不是有效视频JSON（上传阶段失败，仅本地视频）：重新走上传流程
    if (item.contentType == ContentType.video.code &&
        VideoMessageContent.tryParse(item.content) == null) {
      debugPrint("视频消息上传阶段失败，触发重新上传");
      _sendVideoMessage(resendItem: item);
      return;
    }
    // 语音消息：content 有效（上传成功仅 WS 失败）走通用重发；
    // content 为空（异常遗留）但本地文件在则重新上传；否则引导重新录音
    if (item.contentType == ContentType.voice.code &&
        VoiceMessageContent.tryParse(item.content) == null) {
      // 本地临时文件仍在：重新上传该文件重发
      if (item.localVoicePath != null &&
          File(item.localVoicePath!).existsSync()) {
        debugPrint("语音消息上传阶段失败，本地文件仍在，重新上传重发");
        final int seconds = item.localVoiceDuration;
        _sendVoiceMessage(item.localVoicePath!, seconds, resendItem: item);
        return;
      }
      debugPrint("语音消息无有效 content，引导重新录音");
      if (!_isVoiceMode) {
        setState(() => _isVoiceMode = true);
      }
      showTipSnackbar(msg: '语音发送失败，请按住重新录音', isSuccess: false);
      return;
    }
    // 连接不正常时，先触发手动重连（消息入队后会在重连成功时自动消费）
    if (!WebSocketService.instance.canSend) {
      debugPrint("重发时链路不可用，触发手动重连");
      WebSocketService.instance.manualReconnect();
    }
    // 从流放队列取出并重置
    var dto = WebSocketService.instance.ackHelper.resetForResend(
      item.requestId,
    );
    if (dto == null) {
      debugPrint("重发时流放队列未找到消息，尝试重建 dto");
      // 兜底：如果流放队列没有，直接重建 dto（消息可能还在 pending 或已被移除）
      if (item.content == null) return;
      dto = MessageDto(
        msgType: MessageType.chat,
        requestId: item.requestId,
        data: {
          "conversationUid": item.conversationUid,
          "receiverUid": item.receiverUid,
          "contentType": item.contentType,
          "content": item.content,
        },
      );
    }
    // 从发送队列中移除旧消息，避免 sendDto 去重导致不发送
    WebSocketService.instance.removeFromQueue(item.requestId);
    // 更新状态为 pending（转圈）
    item.sendStatus.value = AckStatus.pending;
    // 重新入队发送（连接恢复后自动消费）
    final ok = WebSocketService.instance.sendDto(dto);
    debugPrint("重发入队结果: $ok");
  }

  /// 撤回消息：调用后端撤回接口，成功后本地标记已撤回（撤回广播会同步对方端）
  Future<void> _recallMessage(ChatItem item) async {
    if (item.msgId == null || item.msgId!.isEmpty) {
      // 未入库的消息（乐观渲染中/发送失败）无法撤回，提示后引导删除
      showTipSnackbar(msg: '该消息还未送达，无法撤回，可长按删除', isSuccess: false);
      return;
    }
    final CommonState state = await UserService.recallMessage(
      item.msgId!,
      _chatItem.conversationUid ?? '',
    );
    if (!mounted) return;
    if (state.isSuccess) {
      // 乐观更新本地（撤回广播到达时会再次确认，幂等）
      item.recalled.value = true;
      showTipSnackbar(msg: '已撤回', isSuccess: true);
    } else {
      showTipSnackbar(msg: state.msg, isSuccess: false);
    }
  }

  /// 长按删除消息：本地从列表移除 + 清理本地临时文件（图片/语音上传失败残留）
  void _deleteMessage(ChatItem item) {
    // 清理本地临时文件（未上传成功的图片/语音/视频）
    try {
      if (item.localImagePath != null) {
        final f = File(item.localImagePath!);
        if (f.existsSync()) f.deleteSync();
      }
      if (item.localVoicePath != null) {
        final f = File(item.localVoicePath!);
        if (f.existsSync()) f.deleteSync();
      }
      if (item.localVideoPath != null) {
        final f = File(item.localVideoPath!);
        if (f.existsSync()) f.deleteSync();
      }
    } catch (e) {
      debugPrint('清理本地临时文件异常: $e');
    }
    // 从发送/流放队列移除，避免残留重试
    if (item.requestId != null) {
      WebSocketService.instance.removeFromQueue(item.requestId!);
      WebSocketService.instance.ackHelper.removeFromRoamedList(item.requestId!);
    }
    // 触发列表删除动画
    _messageController.removeChatItem(item);
    debugPrint("删除消息 requestId=${item.requestId}");
    // reverse 列表天然底部对齐（offset 0 即最新消息），删除后底部视图稳定。
    // 仅当删除后 offset 超出新的可滚动范围（顶部内容变短，maxScrollExtent 减小）时，
    // 把 offset 平滑回落回合法位置，避免越界。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final double newMax = pos.maxScrollExtent;
      if (pos.pixels > newMax) {
        _scrollController.animateTo(
          newMax,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
    // 删除过多消息后，若列表条数过少、无法填满屏幕，会导致无法下拉加载历史消息。
    // 此时自动补拉历史消息，保证列表高度足够、滚动区域可下拉。
    if (dataSource.length < 20 && _conversationState.hasMore) {
      debugPrint("删除后消息过少，自动补拉历史消息, 当前=${dataSource.length}");
      _loadHistory(
        conversationUid: _chatItem.conversationUid ?? '',
        pageSize: 20,
      );
    }
  }

  Future<void> _loadHistory({
    String? cursorMsgId,
    required String conversationUid,
    int pageSize = 10,
  }) async {
    if (_isLoadingHistory || !_conversationState.hasMore) return;
    _isLoadingHistory = true;

    CommonState commonState = await UserService.pullHistoryMessage(
      pageSize,
      cursorMsgId,
      conversationUid,
    );
    if (commonState.isSuccess && commonState.data != null) {
      _conversationState.hasMore = commonState.data["hasMore"];
      List? messages = commonState.data["messages"];
      if (messages != null) {
        for (int i = 0; i < messages.length; i++) {
          MessageDispatcher.instance.dispatch(MessageDto.formJson(messages[i]));
        }
        // reverse 列表：历史消息插入顶部（offset 增大方向），底部视图天然稳定，
        // 无需 offset 补偿（补偿反而会破坏倒序稳定性）
      }
    }
    _isLoadingHistory = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 先初始化控制器，再注册滚动监听（_onScroll 依赖 _messageController）
    _messageController = Get.find<MessageController>();
    themeController = Get.find<ThemeController>();
    userController = Get.find<UserController>();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _info = Get.arguments;
    if (_info != null &&
        _info is ChatItem &&
        (_info as ChatItem).conversationUid != "") {
      _isArgumentLegal = true;
      _chatItem = _info as ChatItem;
      _conversationState = _messageController.chatList.getConversationState(
        (_info as ChatItem).conversationUid!,
      );
      dataSource = _conversationState.messageList;
      // 设置活跃会话：此会话在"看历史时"对方新消息将挂起（回到底部再插入）
      _messageController.setActiveConversation(_chatItem.conversationUid);
      if (dataSource.length < 20) {
        // 内容高度不够会导致后面的滑动无法被监听到 因此当缓存的消息过少时 进入聊天界面就加载最近的 20 条历史消息
        _loadHistory(
          conversationUid: (_info as ChatItem).conversationUid!,
          pageSize: 20,
        );
      }
    } else {
      _isArgumentLegal = false;
    }
    _shouldScrollToBottom = true;
    // 订阅 ACK 状态流，更新乐观渲染消息状态
    _ackSub = WebSocketService.instance.ackHelper.ackRespStream.listen((resp) {
      _updateMessageStatus(resp.requestId, resp.ackStatus);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 离开聊天界面：先 flush 挂起的消息（回到底部前离开时也保留消息），再清空活跃会话
    if (_isArgumentLegal && _chatItem.conversationUid != null) {
      _messageController.flushPending(_chatItem.conversationUid!);
    }
    _messageController.setActiveConversation(null);
    _clearUnRead();
    _scrollController.dispose();
    super.dispose();
    _ackSub?.cancel();
  }

  /// 滚动监听：更新是否在底部、同步给 MessageController、到底时 flush 挂起消息
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 聊天列表为 reverse（倒序）：offset 0 即底部（最新消息）。
    // 距底部（offset < 50）视为在底部
    final bool atBottom = position.pixels < 50.0;
    _messageController.setActiveAtBottom(atBottom);
    if (atBottom != _atBottom) {
      _atBottom = atBottom;
      if (atBottom) {
        // 用户回到底部：把"看历史期间挂起的对方消息"批量插入列表（含动画 + 滚动到底）
        _messageController.flushPending(_chatItem.conversationUid!);
      }
    }
  }

  /// 点击"回到底部"按钮：平滑滚动到底并清空未读计数
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    // reverse 列表：offset 0 即底部
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // APP回到前台
      _clearUnRead();
    } else if (state == AppLifecycleState.paused) {
      // APP退后台
      _clearUnRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isArgumentLegal) {
      return Scaffold(body: Center(child: Text("页面参数异常")));
    }

    double screenWidth = MediaQuery.of(context).size.width;
    double safeTopPadding = DeviceSize.instance.statusBarHeight;
    double safeBottomPadding = DeviceSize.instance.bottomGestureHeight;
    final AppTheme t = themeController.currentTheme;
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        child: Container(
          color: t.backGroundColor,
          padding: EdgeInsets.fromLTRB(0, safeTopPadding, 0, 0),
          child: Stack(
            children: [
              Column(
                children: [
                  // 顶部操作栏
                  Container(
                    height: AppBase.topBarHeight,
                    color: t.secondColor,
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: Icon(Icons.arrow_back),
                        ),

                        Text(_chatItem.nickname),
                        IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
                      ],
                    ),
                  ),

                  Obx(() {
                    return AnimatedContainer(
                      height: loadHistoryBox.value,
                      decoration: BoxDecoration(color: t.backGroundColor),
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: Text(
                          _conversationState.hasMore ? "加载历史消息中..." : "已无更多消息",
                        ),
                      ),
                    );
                  }),

                  Expanded(
                    // 或者也可以使用 RefreshIndicator 来进行处理

                    // NotificationListener 让子组件进行滑动时上报给父组件 与 GestureDetector 的区别在于 GestureDetector 的事件是从上往下分发 父->子 而 NotificationListener 的事件是从下往上分发 子-> 父
                    // ScrollStartNotification	手指开始拖动 滚动开始
                    // ScrollUpdateNotification	滚动过程中 持续每帧触发
                    // ScrollEndNotification	滚动停止 手指松开 惯性滚动结束
                    // OverscrollNotification	滚动越界（下拉回弹）

                    // otification.metrics.pixels 当前滚动偏移量
                    // notification.metrics.minScrollExtent 最小滚动位置（ListView头部边界）
                    // notification.metrics.maxScrollExtent 最大滚动位置（ListView尾部边界）
                    // notification.metrics.atEdge 是否已经滚到头部 or 尾部边界
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            // onNotification会极高频率执行 滚动一帧就调用一次
                            onNotification: (ScrollNotification notification) {
                              if (notification is OverscrollNotification) {
                                // 聊天列表为 reverse（倒序）：offset 0 是底部（最新），
                                // 顶部（最早历史）在 maxScrollExtent 端。reverse 列表里
                                // overscroll 符号与正序相反：到达顶部继续下拉时 overscroll > 0。
                                if (notification.overscroll > 0 &&
                                    dataSource.isNotEmpty &&
                                    _conversationState.hasMore) {
                                  loadHistoryBox.value =
                                      notification.overscroll.abs() * 30;
                                }
                              }
                              if (notification is ScrollEndNotification) {
                                if (loadHistoryBox.value > 0) {
                                  const triggerThreshold = 80.0;
                                  if (loadHistoryBox.value >=
                                          triggerThreshold &&
                                      !_isLoadingHistory &&
                                      _conversationState.hasMore) {
                                    _loadHistory(
                                      cursorMsgId: dataSource[0].msgId,
                                      conversationUid:
                                          _chatItem.conversationUid!,
                                    );
                                  }
                                  loadHistoryBox.value = 0;
                                }
                              }
                              // true：拦截事件通知 不再让上层父组件接收
                              // false：事件通知继续向上冒泡 上层组件还可以接收 不拦截滚动
                              return false;
                            },
                            child: CommonAnimatedList(
                              scrollDirection: Axis.vertical,
                              reverse: true,
                              type: ListType.chatList,
                              dataSource: dataSource,
                              eventPaser: (ListEvent event) {
                                if (event is ChatListOperate) {
                                  // 非当前会话的消息不触发插入动画（避免在 A 聊天时 B 的消息执行动画）
                                  if (event.item is ChatItem) {
                                    final ChatItem item =
                                        event.item as ChatItem;
                                    if (item.conversationUid != null &&
                                        item.conversationUid !=
                                            _chatItem.conversationUid) {
                                      return null;
                                    }
                                    // 同步时机决定滚动行为（早于 insertItem，确保 shouldAutoScrollBottom 读到正确值）
                                    if (event.type == ListOperateType.insert) {
                                      final bool isSelf =
                                          (item.senderUid ?? item.uid) ==
                                          userController.uid;
                                      if (item.isInsertToTop) {
                                        // 历史消息插入顶部：不滚动
                                        _shouldScrollToBottom = false;
                                      } else if (!isSelf && !_atBottom) {
                                        // 对方发来新消息 且 用户不在底部：不强制滚动。
                                        // （正常情况下该场景已由 MessageController 挂起，此处为兜底）
                                        _shouldScrollToBottom = false;
                                      } else {
                                        // 自己发消息 或 用户在底部时对方发消息：滑到底
                                        _shouldScrollToBottom = true;
                                      }
                                    }
                                  }
                                  return (
                                    matched: true,
                                    index: event.index,
                                    operateType: event.type,
                                    item: event.item,
                                  );
                                }
                                return null;
                              },
                              insertItemBuilder: (item, animation) {
                                if (item is ChatItem) {
                                  // 判断是不是自己发的消息：优先用 senderUid（发送方），uid 是会话对端语义，系统消息可能不一致
                                  final bool isSelf =
                                      (item.senderUid ?? item.uid) ==
                                      userController.uid;
                                  // 历史消息插入顶部：从上方自然滑入（内容向上延伸），
                                  // 避免横向滑入导致加载历史时闪烁
                                  if (item.isInsertToTop) {
                                    final topTween = Tween<Offset>(
                                      begin: const Offset(0, -0.3),
                                      end: Offset.zero,
                                    );
                                    return SlideTransition(
                                      position: topTween.animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: ChatItemCard(
                                          item: item,
                                          axis: isSelf
                                              ? MainAxisAlignment.end
                                              : MainAxisAlignment.start,
                                          onResend: () => _resendMessage(item),
                                          onDelete: () => _deleteMessage(item),
                                          onRecall: () => _recallMessage(item),
                                        ),
                                      ),
                                    );
                                  }
                                  // 滚动标志已在 eventPaser 中同步设置（此处不再覆盖，避免时机过晚导致覆盖正确值）
                                  final offsetTween = isSelf
                                      ? Tween<Offset>(
                                          begin: const Offset(1, 0),
                                          end: Offset.zero,
                                        )
                                      : Tween<Offset>(
                                          begin: const Offset(-1, 0),
                                          end: Offset.zero,
                                        );

                                  return SlideTransition(
                                    position: offsetTween.animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: ChatItemCard(
                                        item: item,
                                        axis: isSelf
                                            ? MainAxisAlignment.end
                                            : MainAxisAlignment.start,
                                        onResend: () => _resendMessage(item),
                                        onDelete: () => _deleteMessage(item),
                                        onRecall: () => _recallMessage(item),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              deleteItemBuilder: (item, animation) {
                                if (item is! ChatItem)
                                  return const SizedBox.shrink();
                                // 删除动画：气泡向自己方向滑出屏幕 + 淡出
                                final bool isSelf =
                                    (item.senderUid ?? item.uid) ==
                                    userController.uid;
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    // AnimatedList 删除动画 value 从 1 -> 0
                                    final v = animation.value.clamp(0.0, 1.0);
                                    final progress = Curves.easeOutCubic
                                        .transform(1 - v); // 0 -> 1
                                    return Opacity(
                                      opacity: v,
                                      child: Transform.translate(
                                        offset: Offset(
                                          220 * progress * (isSelf ? 1 : -1),
                                          0,
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: ChatItemCard(
                                    item: item,
                                    axis: isSelf
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                  ),
                                );
                              },
                              messageController: _messageController,
                              themeController: themeController,
                              scrollController: _scrollController,
                              shouldAutoScrollBottom: () {
                                final val = _shouldScrollToBottom;
                                if (_shouldScrollToBottom) {
                                  _shouldScrollToBottom = false;
                                }
                                return val;
                              },
                            ),
                          ),
                          // 未滑到底且对方发来新消息时，左下角显示"回到底部"按钮
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Obx(() {
                              final int count =
                                  _messageController.pendingNewMsgCount.value;
                              if (count <= 0) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: _scrollToBottom,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.primaryColor,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: t.primaryColor.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.fromLTRB(
                      10,
                      10,
                      10,
                      10 + safeBottomPadding,
                    ),
                    width: screenWidth,
                    height: 60 + safeBottomPadding,
                    decoration: BoxDecoration(color: t.secondColor),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 多媒体按钮：打开相册多选（图片+视频混合）
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: IconButton(
                              onPressed: _pickAndSendMedia,
                              icon: Icon(Icons.add_circle_outline, size: 26),
                              color: t.fontColor,
                              tooltip: '相册（图片/视频）',
                            ),
                          ),
                        ),
                        // 语音/文本 切换按钮
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: IconButton(
                              onPressed: _toggleVoiceMode,
                              icon: Icon(
                                _isVoiceMode
                                    ? Icons.keyboard_alt_outlined
                                    : Icons.mic_none,
                                size: 26,
                              ),
                              color: _isVoiceMode
                                  ? t.primaryColor
                                  : t.fontColor,
                              tooltip: _isVoiceMode ? '切换文字输入' : '语音输入',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: _isVoiceMode
                              ? _buildHoldToTalkButton(t)
                              : TextFormField(
                                  maxLines: null,
                                  controller: _textEditingController,
                                  // 点击输入框外部时取消光标聚焦（键盘收起）
                                  onTapOutside: (_) {
                                    FocusScope.of(context).unfocus();
                                  },
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                  ),
                                  style: TextStyle(fontSize: 20),
                                ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Material(
                            color: t.secondColor,
                            borderRadius: BorderRadius.circular(5),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                final text = _textEditingController.text.trim();
                                if (text.isEmpty) return;
                                _sendMessageOptimistic(text);
                                _textEditingController.text = "";
                              },
                              splashColor: t.backGroundColor,
                              child: Icon(Icons.send, size: 35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 录音浮动层：覆盖整个聊天页（居中偏上）
              Positioned(
                top: safeTopPadding + 60,
                left: 0,
                right: 0,
                child: _buildRecordOverlay(t),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 录音中的动态波纹指示：三条跳动的音柱（替代"按住说话"按钮内容）
class _RecordingWave extends StatefulWidget {
  final Color color; // 音柱颜色
  const _RecordingWave({this.color = Colors.white});

  @override
  State<_RecordingWave> createState() => _RecordingWaveState();
}

class _RecordingWaveState extends State<_RecordingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double v = _controller.value;
        // 三条音柱错峰跳动
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            // 相位偏移实现错峰
            final double phase = (v - i * 0.18) % 1.0;
            // 正弦波动高度 4 ~ 14
            final double h = 4 + (1 - (phase * 2 - 1).abs()) * 10;
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
