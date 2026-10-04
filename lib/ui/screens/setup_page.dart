import 'package:flutter/material.dart';

import '../../data/scrape_runner.dart';
import '../../data/scraper.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/offline_packs.dart';

enum _Phase { intro, wiki, translation, images, error }

enum _StepState { waiting, running, done, skipped }

/// Màn hình thiết lập lần đầu (hoặc tải lại dữ liệu từ wiki khi [refresh] = true).
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, this.refresh = false});

  final bool refresh;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  _Phase _phase = _Phase.intro;
  ScrapeProgress? _progress;
  String? _error;
  String? _warning;
  _StepState _wikiState = _StepState.waiting;
  _StepState _viState = _StepState.waiting;

  @override
  void initState() {
    super.initState();
    if (widget.refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  Future<void> _run() async {
    final app = AppScope.read(context);
    setState(() {
      _phase = _Phase.wiki;
      _error = null;
      _warning = null;
      _wikiState = _StepState.running;
      _viState = _StepState.waiting;
      _progress = null;
    });

    ScrapeProgress? last;
    await for (final p in ScrapeRunner.run(app.zhDir)) {
      last = p;
      if (mounted) setState(() => _progress = p);
    }
    if (!mounted) return;
    final result = last;
    if (result == null || result.stage != ScrapeStage.done) {
      setState(() {
        _phase = _Phase.error;
        _wikiState = _StepState.waiting;
        _error = result?.message ?? 'Unknown error';
      });
      return;
    }
    setState(() {
      _wikiState = _StepState.done;
      _warning = result.message;
      _phase = _Phase.translation;
      _viState = _StepState.running;
    });

    try {
      await app.syncTranslations(force: true);
      _viState = _StepState.done;
    } catch (_) {
      _viState = _StepState.skipped;
    }
    await app.reloadData();
    app.offline.invalidateCatalog();
    if (!mounted) return;

    if (widget.refresh) {
      app.offline.resumeIfNeeded();
      Navigator.of(context).pop(); // pop() bỏ qua PopScope
      return;
    }
    await app.offline.catalog();
    if (!mounted) return;
    setState(() => _phase = _Phase.images);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    return PopScope(
      canPop: _phase != _Phase.wiki && _phase != _Phase.translation,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 16),
                    Text(
                      widget.refresh ? s.t('refresh_wiki') : s.t('setup_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.t('setup_welcome'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textDim, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    if (_phase == _Phase.intro) ..._intro(app) else ..._steps(app),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _intro(AppController app) {
    final s = app.s;
    return [
      Text(s.t('setup_lang'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'vi', label: Text(s.t('lang_vi'))),
          ButtonSegment(value: 'zh', label: Text(s.t('lang_zh'))),
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
      const SizedBox(height: 24),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: _run,
        icon: const Icon(Icons.download_rounded),
        label: Text(s.t('setup_start'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 10),
      Text(
        s.t('need_internet'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5),
      ),
    ];
  }

  String _stageLabel(ScrapeStage st) {
    final s = AppScope.read(context).s;
    return switch (st) {
      ScrapeStage.category => s.t('stage_category'),
      ScrapeStage.dolls => s.t('stage_dolls'),
      ScrapeStage.weapons => s.t('stage_weapons'),
      ScrapeStage.world => s.t('stage_world'),
      ScrapeStage.media => s.t('stage_media'),
      ScrapeStage.saving => s.t('stage_saving'),
      ScrapeStage.done => s.t('stage_done'),
      ScrapeStage.error => s.t('setup_failed'),
    };
  }

  List<Widget> _steps(AppController app) {
    final s = app.s;
    final p = _progress;
    final wikiDetail = p == null
        ? ''
        : (p.total > 1 ? '${_stageLabel(p.stage)} · ${p.done}/${p.total}' : _stageLabel(p.stage));
    final stageFraction = p == null ? null : (p.stage.index + p.fraction) / ScrapeStage.done.index;

    return [
      _StepTile(
        index: 1,
        title: s.t('setup_step_wiki'),
        state: _wikiState,
        detail: _wikiState == _StepState.running ? wikiDetail : (_warning ?? ''),
        progress: _wikiState == _StepState.running ? stageFraction : null,
      ),
      const SizedBox(height: 10),
      _StepTile(
        index: 2,
        title: s.t('setup_step_vi'),
        state: _viState,
        detail: _viState == _StepState.skipped ? s.t('vi_skipped') : (_viState == _StepState.done ? (app.viMessage ?? '') : ''),
        indeterminate: _viState == _StepState.running,
      ),
      if (!widget.refresh) ...[
        const SizedBox(height: 10),
        _StepTile(
          index: 3,
          title: s.t('setup_step_offline'),
          state: _phase == _Phase.images ? _StepState.running : _StepState.waiting,
          detail: '',
        ),
      ],
      if (_phase == _Phase.error) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          child: Text('${s.t('setup_failed')}\n$_error', style: const TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _run,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(s.t('retry')),
        ),
      ],
      if (_phase == _Phase.images) ...[
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: OfflinePackPanel(
            setupMode: true,
            onDone: () => app.markSetupDone(),
          ),
        ),
      ],
    ];
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, Color(0xFF8C2F00)],
            ),
            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24)],
          ),
          alignment: Alignment.center,
          child: const Text(
            'GF2',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
          ),
        ),
      );
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.state,
    required this.detail,
    this.progress,
    this.indeterminate = false,
  });

  final int index;
  final String title;
  final _StepState state;
  final String detail;
  final double? progress;
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final Widget leading = switch (state) {
      _StepState.done => const Icon(Icons.check_circle_rounded, color: Color(0xFF5BD18B)),
      _StepState.skipped => const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textDim),
      _StepState.running => const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      _StepState.waiting => CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.cardHigh,
          child: Text('$index', style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
        ),
    };
    final showBar = state == _StepState.running && (progress != null || indeterminate);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state == _StepState.running ? AppColors.cardHigh : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: state == _StepState.running ? AppColors.accent.withValues(alpha: 0.5) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 24, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(detail, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
            ),
          ],
          if (showBar) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: indeterminate ? null : progress, minHeight: 6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
