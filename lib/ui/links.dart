import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_controller.dart';
import 'screens/doll_detail_page.dart';
import 'screens/media_detail_page.dart';
import 'screens/story_reader_page.dart';
import 'screens/weapon_detail_page.dart';

/// Mở link trong nội dung: link nội bộ của wiki → mở trang tương ứng trong app,
/// link khác → mở bằng trình duyệt/app ngoài.
void openLink(BuildContext context, String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final app = AppScope.read(context);
  final id = int.tryParse(uri.queryParameters['id'] ?? '');
  if (id != null && uri.host.contains('exiliumgf.com')) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('/doll') && app.data.dollById(id) != null) {
      DollDetailPage.open(context, id);
      return;
    }
    if (path.endsWith('/weapon') && app.data.weaponById(id) != null) {
      WeaponDetailPage.open(context, id);
      return;
    }
    if ((path.endsWith('/settings') || path.endsWith('/setting')) && app.data.worldById(id) != null) {
      StoryReaderPage.open(context, id);
      return;
    }
    if (path.endsWith('/plot') && app.data.mediaById(id) != null) {
      MediaDetailPage.open(context, id);
      return;
    }
  }
  openExternal(context, url);
}

Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
    }
  }
}
