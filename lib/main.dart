import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'state/app_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/setup_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // trình phát video native (PV)
  // Bộ đệm ảnh trong RAM rộng hơn mặc định để cuộn qua lại mượt hơn.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final controller = AppController();
  await controller.init();
  runApp(Gf2WikiApp(controller: controller));
}

class Gf2WikiApp extends StatelessWidget {
  const Gf2WikiApp({super.key, required this.controller});

  final AppController controller;

  // Tạo theme một lần (tránh rebuild/animate theme mỗi khi trạng thái đổi).
  static final ThemeData _theme = buildAppTheme();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        onGenerateTitle: (context) => AppScope.of(context).s.t('app_title'),
        debugShowCheckedModeBanner: false,
        theme: _theme,
        darkTheme: _theme,
        themeMode: ThemeMode.dark,
        scrollBehavior: const AppScrollBehavior(),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: controller.setupDone
                ? const HomeShell(key: ValueKey('home'))
                : const SetupPage(key: ValueKey('setup')),
          ),
        ),
      ),
    );
  }
}
