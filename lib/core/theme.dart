import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// الهوية: أبيض نقي مع أخضر مزرق فخم (Teal) مستخرج من هوية الدائرة + لمسة ذهبية.
const kPrimary =
    Color(0xFF17574E); // Teal: لون الثيم الأساسي (القائمة الجانبية والأزرار)
const kPrimary2 = Color(0xFF3C8C80); // Teal أفتح للرسوم والخطوط الثانوية
const kPrimaryDark = Color(0xFF2E8C7E); // Teal للوضع الداكن
const kGold = Color(0xFFA98545); // ذهبي هادئ للتفاصيل الفخمة
const kBg = Color(0xFFFFFFFF); // خلفية الواجهة البيضاء
const kBorder = Color(0xFFE6EAE8); // separator (فاتح)
const kMuted = Color(0xFF6E6E73); // secondaryLabel (فاتح)
const kRed = Color(0xFFB3261E);
const kText = Color(0xFF111113); // label (فاتح)
const kOlive = Color(0xFF17574E); // توافق قديم
const kOliveDeep = Color(0xFF0E3A34); // توافق قديم

/// ألوان الواجهة الفعلية. تتبدّل بين الفاتح والداكن عبر `Theme.of(context).extension`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg; // خلفية الصفحات
  final Color surface; // البطاقات والحوارات
  final Color surfaceAlt; // أشرطة وصناديق ثانوية
  final Color chrome; // الشريط الجانبي والشريط العلوي
  final Color border; // الفواصل والحدود
  final Color text; // النص الأساسي
  final Color muted; // النص الثانوي
  final Color field; // خلفية حقول الإدخال
  final Color grid; // خطوط الرسوم البيانية

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.chrome,
    required this.border,
    required this.text,
    required this.muted,
    required this.field,
    required this.grid,
  });

  static const light = AppPalette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F6F5),
    chrome: Color(0xFF17574E),
    border: Color(0xFFE6EAE8),
    text: Color(0xFF111113),
    muted: Color(0xFF6E6E73),
    field: Color(0xFFF4F6F5),
    grid: Color(0xFFE9EFED),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0E1111),
    surface: Color(0xFF181C1C),
    surfaceAlt: Color(0xFF212726),
    chrome: Color(0xFF0E3A34),
    border: Color(0xFF2C3433),
    text: Color(0xFFF1F3F2),
    muted: Color(0xFFA2ABA8),
    field: Color(0xFF212726),
    grid: Color(0xFF29302F),
  );

  bool get isDark => bg == dark.bg;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? chrome,
    Color? border,
    Color? text,
    Color? muted,
    Color? field,
    Color? grid,
  }) =>
      AppPalette(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        chrome: chrome ?? this.chrome,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        field: field ?? this.field,
        grid: grid ?? this.grid,
      );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      chrome: Color.lerp(chrome, other.chrome, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      field: Color.lerp(field, other.field, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
    );
  }
}

/// اختصار: `context.p` لألوان الواجهة الحالية.
extension AppPaletteX on BuildContext {
  AppPalette get p =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light);
}

ThemeData buildTheme({bool dark = false}) {
  final p = dark ? AppPalette.dark : AppPalette.light;
  final brightness = dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: brightness,
  ).copyWith(
    primary: dark ? kPrimaryDark : kPrimary,
    secondary: kGold,
    surface: p.surface,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    cardColor: p.surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: dark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
  );
  final shape12 =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    extensions: [p],
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        .apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: kPrimary, width: 1.2)),
      labelStyle: TextStyle(color: p.muted, fontSize: 14),
      hintStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? kPrimaryDark : kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape12,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    // الأزرار الثانوية بأسلوب «Tinted» في iOS: خلفية بلون الثيم الخفيف.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? const Color(0xFF8FDCCF) : kPrimary,
        backgroundColor:
            dark ? kPrimary.withValues(alpha: .28) : const Color(0xFFEAF3F1),
        side: BorderSide.none,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape12,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: dark ? const Color(0xFF8FDCCF) : kPrimary,
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(
          color: dark ? const Color(0xFF5A5F66) : const Color(0xFFC7C7CC),
          width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? (dark ? kPrimaryDark : kPrimary)
              : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: .5, space: 1),
    appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0),
    drawerTheme: DrawerThemeData(backgroundColor: p.chrome),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFF2C3036) : const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white)),
    listTileTheme: ListTileThemeData(textColor: p.text),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface),
  );
}
