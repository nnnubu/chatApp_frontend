# ChatApp Frontend

基于 Flutter + GetX 的即时通讯移动端应用，支持私聊、好友系统、实时消息推送、二维码加好友、图片裁剪上传等功能。配合 [chatApp_backend](https://github.com/nnnubu/chatApp_backend) 后端使用。

## 技术栈

| 类别 | 技术 | 版本 | 在项目中的作用 |
|---|---|---|---|
| 框架 | Flutter | 3.x (Dart 3.10+) | 跨平台移动端 UI |
| 状态管理 | GetX | 4.6.6 | 路由、状态管理、依赖注入、全局控制器 |
| 网络请求 | Dio | 5.4.0 | HTTP 请求（登录、注册、资料等） |
| 实时通信 | web_socket_channel | 2.4.0 | WebSocket 长连接 |
| 本地存储 | shared_preferences | 2.5.5 | 登录态、用户信息持久化 |
| 图片选择 | image_picker | 1.1.0 | 相册选图 / 拍照 |
| 图片裁剪 | crop_your_image | 2.0.0 | 头像/背景图方形裁剪 |
| 图片压缩 | flutter_image_compress | 2.4.0 | 上传前压缩尺寸与质量 |
| 二维码扫描 | mobile_scanner | 5.1.0 | 扫码加好友 |
| 权限管理 | permission_handler | 11.3.1 | 相机、相册权限请求 |
| 应用图标 | flutter_launcher_icons | 0.13.1 | 一键生成多尺寸图标 |
| ID 生成 | nanoid | 1.0.0 | 消息 requestId，用于 ACK 追踪 |

## 系统架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter APP                                  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    页面层 (pages/)                             │  │
│  │  Splash  Login  Register  ResetPwd  Home  ChatPage           │  │
│  │  ProfileEdit  ScanQr  StrangerPreview  CustomCrop             │  │
│  └───────────────────────────┬───────────────────────────────────┘  │
│                              │ 订阅事件 / 调用控制器                   │
│  ┌───────────────────────────▼───────────────────────────────────┐  │
│  │                 GetX 全局控制器 (permanent)                    │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐  │  │
│  │  │UserController│ │ThemeController│ │  MessageController    │  │  │
│  │  │ 用户信息      │ │ 主题切换      │ │  消息/会话状态         │  │  │
│  │  │ 登录态        │ │ 清新绿/暖复古 │ │  聊天列表/未读计数     │  │  │
│  │  │ 本地持久化    │ │ /测试红       │ │                       │  │  │
│  │  └──────┬───────┘ └──────────────┘ └───────────┬───────────┘  │  │
│  └─────────┼───────────────────────────────────────┼──────────────┘  │
│            │                                       │                 │
│  ┌─────────▼───────────────────────────────────────▼──────────────┐  │
│  │                    服务层 (service/ + ws/)                      │  │
│  │                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────┐   │  │
│  │  │          WebSocketService (全局单例)                     │   │  │
│  │  │  串联: 连接器 + 心跳 + ACK + 分发器 + 发送队列            │   │  │
│  │  │                                                         │   │  │
│  │  │  ┌────────────┐  ┌──────────┐  ┌────────────────────┐  │   │  │
│  │  │  │Websocket   │  │HeartBeat │  │   AckHelper        │  │   │  │
│  │  │  │Connector   │  │(ping/pong)│  │(超时重试/流放)     │  │   │  │
│  │  │  │(底层TCP连接)│  │10s/6s/3次│  │8s超时,最多3次      │  │   │  │
│  │  │  └─────┬──────┘  └────┬─────┘  └─────────┬──────────┘  │   │  │
│  │  │        │              │                   │             │   │  │
│  │  │  ┌─────▼──────────────▼───────────────────▼──────────┐  │   │  │
│  │  │  │         事件流 (Stream)                           │  │   │  │
│  │  │  │  StatusChange / MessageEvent / ErrorEvent         │  │   │  │
│  │  │  └───────────────────────┬───────────────────────────┘  │   │  │
│  │  │                          │                              │   │  │
│  │  │  ┌───────────────────────▼───────────────────────────┐  │   │  │
│  │  │  │    MessageDispatcher (消息分发器, 单例)            │  │   │  │
│  │  │  │    handlerMap: msgType → BaseMessageHandler       │  │   │  │
│  │  │  │    ├─ ChatHandler       → MessageListEvent        │  │   │  │
│  │  │  │    ├─ FriendApplyHandler→ MessageListEvent        │  │   │  │
│  │  │  │    └─ CategoryPullHandler→ CategoryListEvent      │  │   │  │
│  │  │  └───────────────────────┬───────────────────────────┘  │   │  │
│  │  │                          │ 广播事件总线                   │   │  │
│  │  │                          ▼                              │   │  │
│  │  │  ┌──────────────────────────────────────────────────┐  │   │  │
│  │  │  │  发送队列 _outGoingQueue (FIFO)                   │  │   │  │
│  │  │  │  连接未就绪时积压, 恢复后自动补发                   │  │   │  │
│  │  │  └──────────────────────────────────────────────────┘  │   │  │
│  │  └─────────────────────────────────────────────────────────┘   │  │
│  │                                                                │  │
│  │  ┌────────────────────┐  ┌────────────────────────────────┐   │  │
│  │  │  UserService       │  │  Utils/                        │   │  │
│  │  │  (Dio HTTP 请求)    │  │  build_static_url / storage    │   │  │
│  │  └────────────────────┘  │  compress_image / permission   │   │  │
│  │                          └────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTP / WS
                               ▼
                    ┌─────────────────────┐
                    │  后端 Go 服务        │
                    │  chatApp_backend    │
                    └─────────────────────┘
```

## WebSocket 服务层组件关系

```
                    WebSocketService (单例, 全局唯一)
                    │
                    ├── WebsocketConnector (底层连接)
                    │   ├── connect(url, token)  → 发起 TCP + WS 握手
                    │   ├── send(dto)           → 写入 WebSocket sink
                    │   ├── disConnect()        → 主动断开
                    │   ├── forceCloseInternal()→ 异常断开
                    │   └── eventStream         → 广播 StatusChange/MessageEvent/ErrorEvent
                    │
                    ├── HeartBeat (心跳检测)
                    │   ├── start()          → 每 10s 发 ping
                    │   ├── resetHeartBeat() → 收到任意消息重置(健康)
                    │   ├── markDead()       → 连续丢 3 次 pong → 死亡
                    │   ├── sendPingCallback → 外部注入发送 ping
                    │   ├── onConnectDead    → 外部注入死亡回调
                    │   └── healthStream     → 健康状态事件流
                    │
                    ├── AckHelper (可靠传输)
                    │   ├── addPendingId(dto)    → 注册 requestId, 启动 8s 超时
                    │   ├── onReciveAck(dto)     → 收到 ack, 移除等待
                    │   ├── onTimeOut(requestId) → 超时, 标记 failed
                    │   ├── _pending Map        → requestId → AckListener
                    │   ├── roamedMsgList        → 超过 3 次重试的流放消息
                    │   ├── resetForResend(id)   → 从流放队列取出重置，供用户手动重发
                    │   └── ackRespStream        → ACK 结果事件流
                    │
                    ├── MessageDispatcher (消息分发)
                    │   ├── registerHandler(list) → 注册各类型处理器
                    │   ├── dispatch(dto)         → 按 msgType 路由到 handler
                    │   ├── _handlerMap           → MessageType → BaseMessageHandler
                    │   └── eventBus              → 处理后广播 MessageBusEvent
                    │
                    ├── _outGoingQueue (发送队列)
                    │   └── FIFO 队列, 连接就绪时消费, 未就绪时积压
                    │
                    └── 重连机制
                        ├── 指数退避: 2s → 4s → 8s → 16s
                        ├── 最多 5 次自动重连
                        ├── 耗尽后 UI 显示手动重连按钮
                        └── 心跳健康时重置退避时间与次数
```

## 核心消息链路

### 一、消息发送链路

```
用户在聊天页输入消息, 点击发送
      │
      ▼
构建 MessageDto {
  msgType: chat,
  requestId: nanoid(),    ← 用于 ACK 追踪
  data: {receiverUID, conversationUID, content}
}
      │
      ▼
WebSocketService.sendDto(dto)
      │
      ├─ 本地乐观插入: 立即构建消息卡片插入聊天列表(AnimatedList 动画)
      │   └─ 状态置为 pending(转圈)
      │
      ├─ 心跳消息 → 直接 send, 不进队列
      └─ 业务消息 → _outGoingQueue.add(dto)
      │
      ▼
_startConsumeOutGoing() (队列消费者, 防并发 _isConsuming)
      │
      ├─ 检查三重门:
      │   1. _connector.status == connected ?
      │   2. _backendReady == true ? (收到后端 ready 信号)
      │   3. _heartBeat.currentHealth != dead ?
      │   任一不满足 → 暂停消费, 消息保留队列, 等待恢复
      │
      ▼ 全部满足
AckHelper.addPendingId(dto)
      │
      ├─ 首次发送: 注册 AckListener{timer:8s, count:1, status:pending}
      ├─ 重试发送: count++, 重建定时器
      └─ count >= 3 → 移除 pending, 加入 roamedMsgList(流放), 推送 roamed 事件
      │
      ▼ 未被流放
_outGoingQueue.removeFirst()  (出队)
      │
      ▼
WebsocketConnector.send(dto)
      │
      ├─ JSON 编码 → _channel.sink.add(str)
      ├─ 返回 true → 消息进入 TCP 缓冲区(不代表后端收到)
      └─ 返回 false → 写回队列, 暂停消费
      │
      ▼  等待 ACK (8s 内)
      │
      ├─ 收到 ack(success=true) →
      │   AckHelper.onReciveAck()
      │     ├─ 移除 _pending[requestId]
      │     ├─ cancel 定时器
      │     ├─ 用后端返回的 msgId 更新 dto
      │     └─ 推送 AckStatus.success
      │         → UI 状态图标: 转圈 → 打勾(已送达)
      │         → 队列继续消费下一条
      │
      ├─ 收到 ack(success=false) →
      │   打印 errMsg, 不自动重试, 等超时
      │
      └─ 8s 超时未收到 ack →
          AckHelper.onTimeOut()
            └─ 推送 AckStatus.failed
                → WebSocketService 监听: 将原始 dto 重新入队
                → 队列再次消费(第2次/第3次)
                → UI 状态图标持续转圈
      │
      ▼  3 次重试均失败 → 流放
AckHelper: 移除 pending, 加入 roamedMsgList
      │
      └─ 推送 AckStatus.roamed
          → UI 状态图标: 转圈 → 感叹号(发送失败)
      │
      ▼  用户点击感叹号 → 手动重发
_resendMessage(item)
      ├─ 链路不可用 → 先触发手动重连(manualReconnect)
      ├─ resetForResend(requestId) → 从流放队列取出并重置状态
      ├─ removeFromQueue() → 移除旧发送队列记录(防重复)
      ├─ 状态置回 pending(转圈)
      └─ sendDto(dto) → 重新入队发送, 重复上述 ACK 流程
```

### 二、消息接收与分发链路

```
后端通过 WebSocket 推送消息
      │
      ▼
WebsocketConnector._channel.stream.listen(rawData)
      │
      ├─ JSON 解码 → MessageDto {msgType, msgId, requestId, data}
      └─ 抛出 MessageEvent(dto) 到 eventStream
      │
      ▼
WebSocketService 监听 eventStream:
      │
      ├─ msgType == ready →
      │   ├─ _backendReady = true
      │   ├─ 取消 5s ready 超时定时器
      │   ├─ HeartBeat.start() 启动心跳
      │   ├─ 唤醒发送队列 _startConsumeOutGoing()
      │   └─ MessageController.initMessagePage() 拉取离线消息
      │
      ├─ msgType == heartBeat (pong) →
      │   └─ HeartBeat.resetHeartBeat() 重置丢失计数(不进分发器)
      │
      ├─ msgType == ack →
      │   └─ AckHelper.onReciveAck(dto) (不进分发器，不过基本上需要ack的消息都是页面自己手动投入分发器 后续可借此拓展监听消息发送状态)
      │
      └─ 其他业务消息 →
          │
          ├─ HeartBeat.resetHeartBeat() (任意消息都重置心跳)
          └─ MessageDispatcher.instance.dispatch(dto)
              │
              ▼
          _handlerMap[dto.msgType] 查找处理器
              │
              ├─ 未注册 → 打印日志, 丢弃
              │
              └─ 找到 handler → handler.handle(dto)
                  │
                  ├─ ChatHandler:
                  │   解析 data → ChatResp
                  │   构建 MessageCardItem
                  │   → MessageListEvent(item)
                  │
                  ├─ FriendApplyHandler:
                  │   解析 data → 好友申请信息
                  │   构建申请消息卡片
                  │   → MessageListEvent(item)
                  │
                  └─ CategoryPullHandler:
                      解析 data → 分类列表
                      → CategoryListEvent(info, item)
                  │
                  ▼
              _eventBus.add(event) 广播到消息总线
                  │
                  ▼
              各页面/控制器订阅 eventBus:
              ├─ 聊天页 → 插入新消息, AnimatedList 动画
              ├─ 首页 → 更新消息分类列表/未读计数
              └─ 好友申请页 → 更新申请列表
```

### 三、连接建立与健康检测完整流程

```
App 启动 / 用户登录后
      │
      ▼
WebSocketService.connect(token)
      │
      ├─ 初始化底层事件监听(仅一次 _initedInternalListener)
      └─ WebsocketConnector.connect(url, token)
          │
          ├─ IOWebSocketChannel.connect(headers: Authorization)
          │   (同步返回, 不等待握手完成)
          ├─ 监听 stream: onData / onError / onDone
          └─ 标记 status = connected
      │
      ▼
等待后端 ready 信号 (5s 超时)
      │
      ├─ 5s 内收到 ready → 就绪, 启动心跳
      └─ 5s 超时 → _forceCloseConnection() → 触发重连
      │
      ▼
心跳循环 (HeartBeat):
      │
      ├─ 每 10s → sendPingCallback() 发送 ping
      │   ├─ 发送失败 → markDead() → 断开重连
      │   └─ 发送成功 → 启动 6s pong 等待定时器
      │
      ├─ 收到任意后端消息 → resetHeartBeat()
      │   ├─ _lostPongCount = 0
      │   ├─ 取消 pong 定时器
      │   └─ 标记 healthy
      │
      └─ pong 6s 超时 → _lostPongCount++
          ├─ < 3 次 → 继续下一轮心跳
          └─ >= 3 次 → markDead()
              └─ onConnectDead → _forceCloseConnection()
      │
      ▼
连接断开 (closed / error / dead):
      │
      ├─ _allowReconnect == true → _reconnect()
      │   ├─ 等待 _reconnectDelay (初始 2s)
      │   ├─ _availableReconnectCount-- (最多 5 次)
      │   ├─ 再次 connect(token)
      │   └─ _reconnectDelay *= 2 (上限 16s)
      │
      ├─ 重连次数耗尽 →
      │   autoReconnectExhausted = true (UI 显示手动重连)
      │
      └─ 重连成功 → 收到 ready →
          重置退避时间(2s) + 次数(5)
          拉取离线消息 + 补发队列积压消息
```

## 已实现功能

### 页面
- **启动页**：初始化全局状态，自动登录跳转
- **登录页**：邮箱 + 密码登录
- **注册页**：邮箱验证码注册
- **重置密码页**：邮箱验证码重置密码
- **首页**：消息分类列表、好友列表、个人中心
- **聊天页**：实时私聊、消息卡片、历史消息下拉加载、发送自动滚动
- **资料编辑页**：头像/背景图上传裁剪、昵称/签名修改
- **二维码扫描页**：扫码加好友
- **陌生人资料预览页**：查看非好友资料、发起好友申请
- **自定义裁剪页**：头像/背景图方形裁剪（手势缩放拖动）

### 好友系统
- 扫码加好友（扫描对方二维码直接发起申请）
- 好友申请列表（待处理申请实时推送）
- 同意 / 拒绝好友申请
- 好友列表展示
- 好友搜索（按昵称搜索，区分是否已是好友，动画展开结果面板）

### 实时通信
- WebSocket 长连接自动重连（指数退避）
- 心跳保活（10s ping / 6s pong / 连续丢 3 次判定死亡）
- 消息 ACK 确认（8s 超时，最多重试 3 次，超过则流放）
- 消息发送状态监测：本地乐观插入 → 转圈 → ACK 打勾 → 失败感叹号
- 失败消息手动重发（点击感叹号，从流放队列取出重新发送）
- 手动重连入口（三态颜色：连接中橙 / 检测健康深橙 / 失败红）
- 多类型消息分发器（聊天/好友申请/分类拉取，可扩展）
- 离线消息拉取（登录后同步未读消息和待处理申请）
- 发送队列（连接未就绪时积压，恢复后自动补发）

### 图片处理
- 相册选图 / 拍照
- 自定义方形裁剪（手势缩放拖动）
- 自动压缩（尺寸 + 质量）
- 上传到后端静态资源服务器
- 静态资源网络请求失败兜底（头像/背景图加载失败显示占位图）

### 状态管理
- 全局字体/文字颜色跟随主题（简介、用户名等文本随背景自适应，避免与背景色混淆）
- GetX 全局常驻控制器：
  - `UserController`：用户信息、登录态、本地持久化
  - `ThemeController`：主题切换（8 套主题：清新绿/暖复古/暗夜黑/海洋蓝/樱花粉/午夜紫/极简白/日落橙，切换图标动画）
  - `MessageController`：全局消息状态、会话管理
  - `BookController`：图书列表、分类、书架状态管理

### 图书模块
- 图书列表拉取（后端分页）
- 图书分类浏览
- 图书详情页
- 我的书架（添加/移除/更新阅读进度）
- 图书搜索
- epub/pdf 阅读器待接入


## 项目结构

```
chatApp_frontend/
├── android/                    # Android 原生配置
├── assets/                     # 静态资源
│   ├── icons/  images/  books/
├── ios/                        # iOS 原生配置
├── lib/
│   ├── api/                    # 网络请求层
│   │   ├── config.dart         # 后端地址配置
│   │   └── user_api.dart       # 用户接口
│   ├── constants/
│   │   └── app_constants.dart  # 消息类型枚举、主题、尺寸常量
│   ├── controller/
│   │   └── global/             # GetX 全局控制器
│   │       ├── user_controller.dart
│   │       ├── theme_controller.dart
│   │       └── messageController/
│   ├── dto/                    # 数据传输对象
│   ├── pages/                  # 页面
│   │   ├── splash.dart  login.dart  register.dart
│   │   ├── resetpwd.dart  home.dart  chat_page.dart
│   │   ├── profile_edit.dart  scan_qr.dart
│   │   ├── stranger_preview.dart  custom_crop.dart
│   ├── service/
│   │   └── user_service.dart   # 用户业务服务
│   ├── utils/                  # 工具函数
│   │   ├── build_static_url.dart
│   │   ├── check_input.dart
│   │   ├── compress_image.dart
│   │   ├── permission_util.dart
│   │   ├── request_id_generator.dart
│   │   ├── show_tip.dart
│   │   └── storage.dart
│   ├── views/                  # 视图组件
│   ├── widgets/                # 通用组件
│   ├── ws/                     # WebSocket 模块
│   │   ├── websocket_client.dart    # 底层连接管理
│   │   ├── websocket_service.dart   # 业务服务层(串联所有组件)
│   │   ├── message_dispatcher.dart  # 消息分发器
│   │   ├── heart_beat.dart          # 心跳管理
│   │   ├── ack_helper.dart          # ACK 可靠传输
│   │   └── message_handler/         # 各类型消息处理器
│   │       ├── base_handler.dart
│   │       ├── message_List/
│   │       │   ├── chat_handler.dart
│   │       │   └── friend_apply_handler.dart
│   │       └── category_list/
│   │           └── category_pull_handler.dart
│   └── main.dart               # 应用入口
├── test/
├── pubspec.yaml
└── README.md
```

## WebSocket 消息类型

| 类型 | 方向 | 说明 |
|---|---|---|
| `ready` | 后端→前端 | 连接建立成功，后端就绪 |
| `heartBeat` | 双向 | 心跳 ping/pong |
| `chat` | 双向 | 聊天消息 |
| `addFriend` | 后端→前端 | 好友申请通知 |
| `argee` | 后端→前端 | 好友申请被同意 |
| `refuse` | 后端→前端 | 好友申请被拒绝 |
| `markRead` | 前端→后端 | 标记已读 |
| `ack` | 后端→前端 | 消息送达确认（携带 requestId） |
| `pullCategory` | 双向 | 拉取消息分类 |

## 快速开始

### 环境要求
- Flutter 3.x（Dart 3.10+）
- Android Studio / VS Code
- Android 模拟器或真机（最低 SDK 21）

### 步骤

1. 克隆仓库
```bash
git clone https://github.com/nnnubu/chatApp_frontend.git
cd chatApp_frontend
```

2. 配置后端地址

编辑 `lib/api/config.dart`：
```dart
class ApiConfig {
  static const String _baseServer = "你的后端地址:端口";
  static const String baseUrl = "http://${ApiConfig._baseServer}";
  static const String wsUrl = "ws://${ApiConfig._baseServer}";
}
```

> 开发用 `http`/`ws` 明文。Android 9+ 默认禁止明文 HTTP，需在 `AndroidManifest.xml` 的 `<application>` 标签添加 `android:usesCleartextTraffic="true"`。

3. 安装依赖
```bash
flutter pub get
```

4. 运行
```bash
flutter run
```

### 打包 APK
```bash
flutter build apk --release
```
## 应用界面展示

### 一、账户与登录流程

| 启动页 | 登录页 |
|---|---|
| ![image-20260831205247868](assets\images\image-20260831205247868.png) | ![image-20260831224801823](assets\images\image-20260831224801823.png) |
| **注册页** | **重置密码页** |
| ![image-20260831225256577](assets\images\image-20260831225256577.png) | ![image-20260831225248160](assets\images\image-20260831225248160.png) |

### 二、首页与消息中心

| 首页-消息分类 | 首页-好友列表展开 | 好友搜索 |
|---|---|---|
| ![image-20260831232023394](assets\images\image-20260831232023394.png) | ![image-20260831205821868](assets\images\image-20260901000353146.png) | ![image-20260831232106873](assets\images\image-20260831232106873.png) |

### 三、聊天与实时通信

| 聊天页-消息气泡 | 聊天页-发送状态（打勾/转圈/感叹号） | 消息列表-长列表 |
|---|---|---|
| ![image-20260831205438222](assets\images\image-20260831205438222.png) | ![image-20260831205557478](assets\images\image-20260831205557478.png) | ![image-20260831232237872](assets\images\image-20260831232237872.png) |

> 发送状态示意图：发送中转圈 → ACK 成功后打勾 → 发送失败感叹号（可点击重发）。

### 四、好友与陌生人

| 陌生人主页 | 好友主页 | 好友申请 |
|---|---|---|
| ![image-20260831205927915](assets\images\image-20260831205927915.png) | ![image-20260831205624142](assets\images\image-20260831205624142.png) | ![image-20260831231919780](assets\images\image-20260831231919780.png) |

### 五、个人中心与资料编辑

| 个人中心                                                     | 资料编辑                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| ![image-20260831225400125](assets\images\image-20260831225400125.png) | ![image-20260831225427997](assets\images\image-20260831225427997.png) |

### 六、图书模块

| 图书列表 | 图书详情 | 我的书架 | 图书搜索 |
|---|---|---|---|
| ![image-20260831225634033](assets\images\image-20260831225634033.png) | ![image-20260831225653426](assets\images\image-20260831225653426.png) | ![image-20260831225723189](assets\images\image-20260831225723189.png) | ![image-20260831225746345](assets\images\image-20260831225746345.png) |

### 七、主题切换

| 清新绿 | 暖复古 | 暗夜黑 | 海洋蓝 |
|---|---|---|---|
| ![image-20260831232839611](assets\images\image-20260831232839611.png) | ![image-20260831232852362](assets\images\image-20260831232852362.png) | ![image-20260831232905074](assets\images\image-20260831232905074.png) | ![image-20260831232917083](assets\images\image-20260831232917083.png) |

| 樱花粉 | 午夜紫 | 极简白 | 日落橙 |
|---|---|---|---|
| ![image-20260831232934901](assets\images\image-20260831232934901.png) | ![image-20260831232948547](assets\images\image-20260831232948547.png) | ![image-20260831232958414](assets\images\image-20260831232958414.png) | ![image-20260831233010962](assets\images\image-20260831233010962.png) |

---

## 项目难点与设计思考

1. **消息可靠传输**：发送时生成 `requestId`，等待后端 ACK，8s 超时自动重试，最多 3 次，超过则流放并提示用户，保障消息不丢失
2. **三重连接状态判定**：`WebSocketStatus.connected`（TCP 通道）+ `ready`（后端业务就绪）+ `ConnectionHealth.healthy`（心跳验证双向通信），避免半开放连接
3. **静默断网检测**：TCP 重传超时前无法感知断连，用心跳 ping/pong + 连续丢失阈值主动判定，而非依赖底层 IO 异常
4. **指数退避重连**：断网瞬间大量重连会造成重连风暴，用 2→4→8→16s 退避，心跳健康后自动重置
5. **发送队列积压**：连接未就绪时消息不丢弃，进入 FIFO 队列，连接恢复后自动补发，用户体验无感知
6. **消息分发器模式**：统一入口按 `msgType` 路由到对应 handler，新增消息类型只需注册新处理器
7. **每连接单消费协程**：后端 WebSocket 同一连接多协程并发 `WriteMessage` 会报文错乱，用管道 + 单消费协程串行写入
8. **GetX 常驻控制器**：用户/主题/消息三个控制器设为 `permanent`，跨页面共享状态，登录态通过 `shared_preferences` 持久化
9. **聊天列表性能**：`AnimatedList` 插入动画 + 游标分页加载 + 图片缓存限制 10MB，避免长列表内存溢出
10. **发送状态监测**：本地乐观插入即时反馈，ACK 结果驱动状态图标流转（转圈→打勾/感叹号），失败消息进入流放队列等待用户手动重发，兼顾即时体验与最终一致性
11. **手动重发与链路自愈**：感叹号点击触发重发时，若链路不可用先自动触发手动重连，流放消息出队重置后重新入队发送
12. **AnimatedList 事件缓存**：列表未挂载（如高度动画期间）时缓存插入/删除事件，build 完成后批量回放，避免动画事件丢失
13. **主题字体自适应**：文字颜色随主题背景动态适配，简介等覆盖在背景图上的文本不因颜色相近而不可读

## 待开发

- [ ] 群聊功能
- [x] 修复会话插入消息时未隔离动画的问题
- [ ] 图片/文件/语音消息
- [ ] 消息撤回
- [x] 消息重发与发送状态监测（本地乐观插入、ACK状态展示、失败可重发）
- [ ] 消息搜索
- [x] 读书模块框架搭建（图书列表/分类/书架/详情/搜索，epub/pdf 阅读器待接入）
- [ ] 离线推送通知（指用户不登录软件 通过系统通知消息）
- [ ] 用户高频访问信息缓存本地 （预计 Isar 来做业务持久缓存，cached_network_image 做图片/二进制资源缓存，Drift(SQLite) 做聊天消息缓存）

## 相关仓库

- 后端服务：[chatApp_backend](https://github.com/nnnubu/chatApp_backend)
