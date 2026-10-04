import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/html_content.dart';

/// Chi tiết một mục "Tư liệu khác" (PV, radio, hình nền).
class MediaDetailPage extends StatelessWidget {
  const MediaDetailPage({super.key, required this.id});

  final int id;

  static Future<void> open(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailPage(id: id)));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final m = app.data.mediaById(id);
    if (m == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(message: s.t('error_load')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(m.title, overflow: TextOverflow.ellipsis),
        actions: const [LangToggleButton(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          MaxWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Container(width: 40, height: 3, color: AppColors.accent),
                const SizedBox(height: 14),
                if (m.html.trim().isEmpty)
                  EmptyState(message: s.t('no_data'))
                else
                  HtmlContent(m.html, videoCover: m.cover),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
