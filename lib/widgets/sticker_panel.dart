import 'dart:io';

import 'package:chatapp/api/user_api.dart';
import 'package:chatapp/cache/cache_keys.dart';
import 'package:chatapp/cache/isar_cache_service.dart';
import 'package:chatapp/utils/show_tip.dart';
import 'package:chatapp/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 用户自定义表情包面板
/// 底部弹出，网格展示用户收藏的表情包，支持添加/删除/点击发送
class StickerPanel extends StatefulWidget {
  final Function(String url, String? stickerId) onSendSticker;

  const StickerPanel({super.key, required this.onSendSticker});

  /// 便捷弹出方法
  static Future<void> show(
    BuildContext context,
    Function(String url, String? stickerId) onSend,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPanel(onSendSticker: onSend),
    );
  }

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  final _stickers = <Map<String, dynamic>>[].obs;
  final _loading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    // 1. 先读缓存，有数据则立即显示（try-catch 兜底）
    bool hasCache = false;
    try {
      final cached = await IsarCacheService.instance.getJson(CacheKeys.userStickers);
      if (cached != null) {
        final list = (cached['list'] as List?) ?? [];
        _stickers
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(list));
        _loading.value = false;
        hasCache = true;
      }
    } catch (_) {}

    // 2. 再拉网络，成功后回写缓存（TTL 24小时）
    try {
      final res = await UserApi.pullStickers();
      if (res != null) {
        final list = (res['list'] as List?) ?? [];
        _stickers
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(list));
        _loading.value = false;
        await IsarCacheService.instance.setJson(
          CacheKeys.userStickers,
          {'list': list},
          ttlSeconds: 24 * 60 * 60,
        );
        return;
      }
    } catch (_) {}
    // 网络失败且无缓存时才结束 loading
    if (!hasCache) _loading.value = false;
  }

  Future<void> _addSticker() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
        ),
      );
      if (result == null || result.isEmpty) return;
      final File? file = await result.first.file;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final res = await UserApi.uploadSticker(bytes, ext);
      // 拦截器已剥离 code/message，成功时 res 为 {id, url}，失败时为 null
      if (res != null) {
        if (mounted) showTipSnackbar(msg: '添加成功', isSuccess: true);
        _loadStickers();
      } else {
        if (mounted) showTipSnackbar(msg: '添加失败，请重试', isSuccess: false);
      }
    } catch (_) {
      if (mounted) showTipSnackbar(msg: '添加失败，请重试', isSuccess: false);
    }
  }

  Future<void> _confirmDelete(String id, String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除表情包'),
        content: const Text('确定要删除这张表情包吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // deleteSticker 成功时后端返回无 data，拦截器后 res 可能为 null；
      // 不依赖返回值，直接乐观移除本地列表并提示
      await UserApi.deleteSticker(id);
      _stickers.removeWhere((s) => s['id'] == id);
      showTipSnackbar(msg: '已删除', isSuccess: true);
    } catch (_) {
      showTipSnackbar(msg: '删除失败，请重试', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Obx(() => Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('我的表情包',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color)),
                const Spacer(),
                Text('${_stickers.length} 张',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
          const Divider(height: 1),
          // 网格区域
          Expanded(
            child: _loading.value
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _stickers.length + 1,
                    itemBuilder: (context, index) {
                      // 最后一格：添加按钮
                      if (index == _stickers.length) {
                        return GestureDetector(
                          onTap: _addSticker,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.add,
                                color: theme.colorScheme.primary, size: 28),
                          ),
                        );
                      }
                      final sticker = _stickers[index];
                      final url = sticker['url'] as String? ?? '';
                      final id = sticker['id'] as String?;
                      return GestureDetector(
                        onTap: () {
                          widget.onSendSticker(url, id);
                          Navigator.pop(context);
                        },
                        onLongPress: () {
                          if (id != null) _confirmDelete(id, url);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AppImage(
                            imageUrl: url,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            type: AppImageType.general,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      )),
    );
  }
}
