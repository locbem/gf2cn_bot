import 'package:flutter/material.dart';

import '../../core/file_cache.dart';
import '../../data/image_catalog.dart';
import '../../state/app_controller.dart';
import '../../state/offline_downloader.dart';
import '../theme.dart';

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

IconData _iconOf(OfflinePack p) => switch (p) {
      OfflinePack.basic => Icons.image_outlined,
      OfflinePack.images => Icons.photo_library_outlined,
      OfflinePack.gifs => Icons.gif_box_outlined,
      OfflinePack.voices => Icons.record_voice_over_outlined,
    };

/// Chọn & tải các gói offline (ảnh cơ bản, ảnh chi tiết, ảnh động, lồng tiếng).
/// Dùng ở màn hình thiết lập lần đầu ([setupMode]) và trong Cài đặt.
class OfflinePackPanel extends StatefulWidget {
  const OfflinePackPanel({super.key, this.setupMode = false, this.onDone});

  final bool setupMode;

  /// Gọi sau khi bấm Tải / Để sau (chế độ thiết lập).
  final VoidCallback? onDone;

  @override
  State<OfflinePackPanel> createState() => _OfflinePackPanelState();
}

class _OfflinePackPanelState extends State<OfflinePackPanel> {
  Set<OfflinePack>? _sel;
  Future<int>? _usage;

  @override
  void initState() {
    super.initState();
    final dl = AppScope.read(context).offline;
    dl.refreshCounts();
    _refreshUsage();
  }

  void _refreshUsage() {
    _usage = Future.wait([imageFiles.diskUsage(), audioFiles.diskUsage()]).then((v) => v[0] + v[1]);
  }

  Set<OfflinePack> _selection(OfflineDownloader dl) {
    final current = _sel;
    if (current != null) return current;
    final saved = dl.selected;
    return saved.isNotEmpty ? saved : (widget.setupMode ? {OfflinePack.basic} : <OfflinePack>{});
  }

  Future<void> _clear() async {
    final app = AppScope.read(context);
    final s = app.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.t('clear_offline_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    await app.offline.clearSelection();
    await imageFiles.clear();
    await audioFiles.clear();
    PaintingBinding.instance.imageCache.clear();
    await app.offline.refreshCounts();
    if (mounted) {
      setState(() {
        _sel = <OfflinePack>{};
        _refreshUsage();
      });
    }
  }

  String _packTitle(OfflinePack p) => context.s.t('pack_${p.name}');
  String _packDesc(OfflinePack p) => context.s.t('pack_${p.name}_desc');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final dl = app.offline;
    return ListenableBuilder(
      listenable: dl,
      builder: (context, _) {
        final sel = _selection(dl);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(s.t('offline_hint'), style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.45)),
            ),
            for (final p in OfflinePack.values)
              CheckboxListTile(
                value: sel.contains(p),
                onChanged: dl.running
                    ? null
                    : (v) => setState(() {
                          final next = {...sel};
                          if (v == true) {
                            next.add(p);
                          } else {
                            next.remove(p);
                          }
                          _sel = next;
                        }),
                secondary: Icon(_iconOf(p), color: dl.running && dl.current == p ? AppColors.accent : AppColors.textDim),
                title: Text(_packTitle(p), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    _packDesc(p),
                    s.t('pack_files', {'n': dl.packTotal[p] ?? '…', 'size': p.estimate}),
                    if (!widget.setupMode && (dl.packTotal[p] ?? 0) > 0)
                      s.t('pack_saved', {'d': dl.packDone[p] ?? 0, 't': dl.packTotal[p]}),
                  ].join('\n'),
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
                isThreeLine: true,
                controlAffinity: ListTileControlAffinity.trailing,
                activeColor: AppColors.accent,
              ),
            if (dl.running || dl.preparing) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: dl.preparing ? null : dl.fraction, minHeight: 6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                child: Text(
                  s.t('downloading_pack', {
                    'pack': dl.current == null ? '' : _packTitle(dl.current!),
                    'd': dl.done,
                    't': dl.total,
                  }),
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
              ),
            ] else if (!widget.setupMode && dl.isComplete)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                child: Text(s.t('offline_done'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              ),
            if (!widget.setupMode)
              FutureBuilder<int>(
                future: _usage,
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    s.t('offline_status', {
                      'n': imageFiles.count + audioFiles.count,
                      'size': snap.hasData ? formatBytes(snap.data!) : '…',
                    }),
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (dl.running)
                    FilledButton.tonalIcon(
                      onPressed: dl.pause,
                      icon: const Icon(Icons.pause_rounded),
                      label: Text(s.t('pause')),
                    )
                  else
                    FilledButton.icon(
                      onPressed: sel.isEmpty && !widget.setupMode
                          ? null
                          : () {
                              dl.start(sel);
                              widget.onDone?.call();
                            },
                      icon: const Icon(Icons.download_rounded),
                      label: Text(sel.isEmpty ? s.t('enter_app') : s.t('download_selected')),
                    ),
                  if (widget.setupMode)
                    TextButton(
                      onPressed: () {
                        dl.clearSelection();
                        widget.onDone?.call();
                      },
                      child: Text(s.t('img_skip')),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: dl.running ? null : _clear,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(s.t('clear_offline')),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
