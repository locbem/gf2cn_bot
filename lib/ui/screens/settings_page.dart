import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/json_merge.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/offline_packs.dart';
import 'setup_page.dart';

String formatTime(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return iso;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: const [
            _LanguageSection(),
            _DisplaySection(),
            _TranslationSection(),
            _WikiSection(),
            _OfflineSection(),
            _FolderSection(),
            _AboutSection(),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      );
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    return _Group(title: s.t('language'), children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'vi', label: Text(s.t('lang_vi')), icon: const Text('VI')),
            ButtonSegment(value: 'zh', label: Text(s.t('lang_zh')), icon: const Text('中')),
          ],
          selected: {app.lang},
          showSelectedIcon: false,
          onSelectionChanged: (v) => app.setLang(v.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.2),
            selectedForegroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.line),
          ),
        ),
      ),
    ]);
  }
}

class _DisplaySection extends StatelessWidget {
  const _DisplaySection();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    return _Group(title: s.t('display'), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            Expanded(child: Text(s.t('text_size'))),
            Text('${(app.textScale * 100).round()}%', style: const TextStyle(color: AppColors.textDim)),
          ],
        ),
      ),
      Slider(
        value: app.textScale,
        min: 0.85,
        max: 1.4,
        divisions: 11,
        onChanged: app.setTextScale,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          '人形、武器、世界设定 – Nhân vật, vũ khí, thiết lập thế giới.',
          style: TextStyle(fontSize: 15 * app.textScale, height: 1.6, color: AppColors.textDim),
        ),
      ),
    ]);
  }
}

class _TranslationSection extends StatelessWidget {
  const _TranslationSection();

  Future<void> _editSource(BuildContext context) async {
    final app = AppScope.read(context);
    final s = app.s;
    final repo = TextEditingController(text: app.githubRepo);
    final branch = TextEditingController(text: app.githubBranch);
    final path = TextEditingController(text: app.githubPath);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('edit_source')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: repo,
                decoration: InputDecoration(labelText: s.t('repo'), hintText: s.t('repo_hint')),
              ),
              const SizedBox(height: 10),
              TextField(controller: branch, decoration: InputDecoration(labelText: s.t('branch'))),
              const SizedBox(height: 10),
              TextField(controller: path, decoration: InputDecoration(labelText: s.t('folder'))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('save'))),
        ],
      ),
    );
    if (ok == true) {
      await app.setSource(repo: repo.text, branch: branch.text, path: path.text);
      if (context.mounted) await _check(context);
    }
    repo.dispose();
    branch.dispose();
    path.dispose();
  }

  Future<void> _check(BuildContext context) async {
    final app = AppScope.read(context);
    try {
      await app.syncTranslations(force: true);
    } catch (_) {
      // Thông báo lỗi đã được lưu trong app.viMessage.
    }
    if (context.mounted && app.viMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.viMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final version = jStr(app.data.viManifest['version']);
    final running = app.viStatus == SyncStatus.running;
    return _Group(title: s.t('translation'), children: [
      ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: Text(app.githubRepo),
        subtitle: Text('${app.githubBranch} · ${app.githubPath.isEmpty ? '/' : app.githubPath}'),
        trailing: IconButton(
          tooltip: s.t('edit_source'),
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editSource(context),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.translate_rounded),
        title: Text(version.isEmpty ? s.t('translation_none') : s.t('translation_version', {'v': formatTime(version)})),
        subtitle: app.viMessage == null
            ? null
            : Text(
                app.viMessage!,
                style: TextStyle(color: app.viStatus == SyncStatus.error ? Colors.redAccent : AppColors.textDim),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: running ? null : () => _check(context),
            icon: running
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            label: Text(running ? s.t('syncing') : s.t('check_update')),
          ),
        ),
      ),
    ]);
  }
}

class _WikiSection extends StatelessWidget {
  const _WikiSection();

  Future<void> _refresh(BuildContext context) async {
    final s = AppScope.read(context).s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.t('refresh_wiki_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SetupPage(refresh: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final m = app.data.zhManifest;
    final counts = jMap(m['counts']);
    return _Group(title: s.t('wiki_data'), children: [
      ListTile(
        leading: const Icon(Icons.dataset_outlined),
        title: Text(s.t('wiki_updated_at', {'t': formatTime(jStr(m['version']))})),
        subtitle: Text(s.t('wiki_counts', {
          'd': jInt(counts['dolls'], app.data.dolls.length),
          'w': jInt(counts['weapons'], app.data.weapons.length),
          's': jInt(counts['world'], app.data.world.length),
          'm': jInt(counts['media'], app.data.media.length),
        })),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _refresh(context),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(s.t('refresh_wiki')),
          ),
        ),
      ),
    ]);
  }
}

class _OfflineSection extends StatelessWidget {
  const _OfflineSection();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return _Group(title: s.t('offline_title'), children: const [OfflinePackPanel()]);
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    return _Group(title: s.t('data_folder'), children: [
      ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: SelectableText(app.dataRoot, style: const TextStyle(fontSize: 13)),
        trailing: Platform.isWindows || Platform.isLinux || Platform.isMacOS
            ? IconButton(
                tooltip: s.t('open_folder'),
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => launchUrl(Uri.directory(app.dataRoot)),
              )
            : null,
      ),
    ]);
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return _Group(title: s.t('about'), children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(s.t('about_text'), style: const TextStyle(color: AppColors.textDim, height: 1.6)),
      ),
    ]);
  }
}
