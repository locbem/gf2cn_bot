import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Bảng màu tối lấy cảm hứng từ giao diện wiki GF2 (nền xám than, điểm nhấn cam).
class AppColors {
  AppColors._();

  static const Color accent = Color(0xFFF26C1C);
  static const Color accentSoft = Color(0xFFFF9A5A);
  static const Color bg = Color(0xFF0E1014);
  static const Color surface = Color(0xFF151920);
  static const Color card = Color(0xFF1B2028);
  static const Color cardHigh = Color(0xFF232933);
  static const Color line = Color(0xFF2C333F);
  static const Color text = Color(0xFFE9EBEF);
  static const Color textDim = Color(0xFF9BA4B4);
  static const Color textFaint = Color(0xFF6B7484);
  static const Color blue = Color(0xFF33A4DA);

  static const Color rarityElite = Color(0xFFFFB547);
  static const Color rarityStandard = Color(0xFFA77BFF);
  static const Color rarityOld = Color(0xFF5B9BEF);

  /// Màu theo id thuộc tính (异位属性) của API.
  static Color attr(int id) => switch (id) {
        1 => const Color(0xFFB8C0CC), // 物理
        2 => const Color(0xFFFF6B3D), // 燃烧
        3 => const Color(0xFF8F86FF), // 电导
        4 => const Color(0xFF4FC3F7), // 冷凝
        5 => const Color(0xFF9CCC65), // 酸蚀
        6 => const Color(0xFFC77DFF), // 浊刻
        32 => const Color(0xFFFFD54F), // 源谐
        _ => textDim,
      };

  /// Màu độ hiếm nhân vật (5 = tinh anh, 4 = tiêu chuẩn).
  static Color dollRarity(int level) => level >= 5 ? rarityElite : rarityStandard;

  /// Màu độ hiếm vũ khí (5 精英, 4 标准, 3 旧式).
  static Color weaponRarity(int r) => switch (r) {
        >= 5 => rarityElite,
        4 => rarityStandard,
        _ => rarityOld,
      };
}

/// Biểu tượng cho lớp nhân vật (职业) theo id.
IconData roleIcon(int id) => switch (id) {
      1 => Icons.shield_outlined, // 防卫
      2 => Icons.bolt_rounded, // 尖兵
      3 => Icons.healing_rounded, // 支援
      4 => Icons.gps_fixed_rounded, // 火力
      _ => Icons.person_outline,
    };

/// Theme tối. Chỉ dùng các lớp *ThemeData ổn định qua nhiều phiên bản Flutter;
/// Card/TabBar/TextField được style trực tiếp trong widget.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.accentSoft,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textDim,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textDim,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textDim),
      selectedLabelTextStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textDim),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.accent.withValues(alpha: 0.22),
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cardHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.textDim),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.line,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}

/// Ô nhập dạng "pill" dùng cho ô tìm kiếm.
InputDecoration searchDecoration(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textDim),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      hintStyle: const TextStyle(color: AppColors.textFaint),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
    );

/// TabBar có style thống nhất.
TabBar appTabBar({required List<Widget> tabs, TabController? controller, bool scrollable = true}) => TabBar(
      controller: controller,
      tabs: tabs,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.line,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
      overlayColor: WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.08)),
    );

/// Cho phép kéo bằng chuột trên Windows (danh sách ngang, PageView...).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
