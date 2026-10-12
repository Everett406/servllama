import 'package:flutter/material.dart';
import 'package:servllama/app/design/tokens.dart';

/// Bridges the warm Claude palette onto Material's [ColorScheme] so stock
/// widgets (dialogs, scrollbars, text selection handles) stop looking like
/// a different app. Only the roles that stock widgets actually read are set
/// explicitly; the rest stay at Material defaults so we inherit sane
/// behaviour rather than pin down every field.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.sidebar,
    required this.surface,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentSubtle,
    required this.okText,
    required this.warningText,
    required this.dangerText,
    required this.engineLlama,
    required this.engineMnn,
    required this.okMark,
    required this.warningMark,
    required this.dangerMark,
    required this.idleMark,
  });

  static const light = AppColors(
    canvas: ClaudeColors.canvas,
    sidebar: ClaudeColors.sidebar,
    surface: ClaudeColors.surface,
    surfaceSunken: ClaudeColors.surfaceSunken,
    border: ClaudeColors.border,
    borderStrong: ClaudeColors.borderStrong,
    textPrimary: ClaudeColors.textPrimary,
    textSecondary: ClaudeColors.textSecondary,
    textTertiary: ClaudeColors.textTertiary,
    accentSubtle: ClaudeColors.accentSubtle,
    okText: ClaudeColors.okText,
    warningText: ClaudeColors.warningText,
    dangerText: ClaudeColors.dangerText,
    engineLlama: ClaudeColors.engineLlama,
    engineMnn: ClaudeColors.engineMnn,
    okMark: ClaudeColors.ok,
    warningMark: ClaudeColors.warning,
    dangerMark: ClaudeColors.danger,
    idleMark: ClaudeColors.idle,
  );

  static const dark = AppColors(
    canvas: ClaudeColors.canvasDark,
    sidebar: ClaudeColors.sidebarDark,
    surface: ClaudeColors.surfaceDark,
    surfaceSunken: ClaudeColors.surfaceSunkenDark,
    border: ClaudeColors.borderDark,
    borderStrong: ClaudeColors.borderStrongDark,
    textPrimary: ClaudeColors.textPrimaryDark,
    textSecondary: ClaudeColors.textSecondaryDark,
    textTertiary: ClaudeColors.textTertiaryDark,
    accentSubtle: ClaudeColors.accentSubtleDark,
    okText: ClaudeColors.okTextDark,
    warningText: ClaudeColors.warningTextDark,
    dangerText: ClaudeColors.dangerTextDark,
    engineLlama: ClaudeColors.engineLlamaDark,
    engineMnn: ClaudeColors.engineMnnDark,
    okMark: ClaudeColors.ok,
    warningMark: ClaudeColors.warning,
    dangerMark: ClaudeColors.danger,
    idleMark: ClaudeColors.idleDark,
  );

  final Color canvas;
  final Color sidebar;
  final Color surface;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentSubtle;
  final Color okText;
  final Color warningText;
  final Color dangerText;
  final Color engineLlama;
  final Color engineMnn;
  final Color okMark;
  final Color warningMark;
  final Color dangerMark;
  final Color idleMark;

  @override
  AppColors copyWith({
    Color? canvas,
    Color? sidebar,
    Color? surface,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentSubtle,
    Color? okText,
    Color? warningText,
    Color? dangerText,
    Color? engineLlama,
    Color? engineMnn,
    Color? okMark,
    Color? warningMark,
    Color? dangerMark,
    Color? idleMark,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      okText: okText ?? this.okText,
      warningText: warningText ?? this.warningText,
      dangerText: dangerText ?? this.dangerText,
      engineLlama: engineLlama ?? this.engineLlama,
      engineMnn: engineMnn ?? this.engineMnn,
      okMark: okMark ?? this.okMark,
      warningMark: warningMark ?? this.warningMark,
      dangerMark: dangerMark ?? this.dangerMark,
      idleMark: idleMark ?? this.idleMark,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      okText: Color.lerp(okText, other.okText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      engineLlama: Color.lerp(engineLlama, other.engineLlama, t)!,
      engineMnn: Color.lerp(engineMnn, other.engineMnn, t)!,
      okMark: Color.lerp(okMark, other.okMark, t)!,
      warningMark: Color.lerp(warningMark, other.warningMark, t)!,
      dangerMark: Color.lerp(dangerMark, other.dangerMark, t)!,
      idleMark: Color.lerp(idleMark, other.idleMark, t)!,
    );
  }
}

extension AppColorsX on ThemeData {
  AppColors get colors =>
      extension<AppColors>() ??
      (brightness == Brightness.light ? AppColors.light : AppColors.dark);
}

/// Convenience shorthands so widget code reads as `context.accent`
/// instead of `ClaudeColors.accent` or a field off the extension.
extension AppAccentX on BuildContext {
  AppColors get _c => Theme.of(this).colors;
  Color get accent => ClaudeColors.accent;
  Color get accentPressed => ClaudeColors.accentPressed;
  Color get canvas => _c.canvas;
  Color get sidebar => _c.sidebar;
  Color get surface => _c.surface;
  Color get surfaceSunken => _c.surfaceSunken;
  Color get border => _c.border;
  Color get borderStrong => _c.borderStrong;
  Color get ink => _c.textPrimary;
  Color get inkSecondary => _c.textSecondary;
  Color get inkTertiary => _c.textTertiary;
  Color get accentSubtle => _c.accentSubtle;
  Color get okText => _c.okText;
  Color get warningText => _c.warningText;
  Color get dangerText => _c.dangerText;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _buildTheme(AppColors.light);

  static ThemeData dark() => _buildTheme(AppColors.dark);

  static ThemeData _buildTheme(AppColors c) {
    final isDark = c == AppColors.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ClaudeColors.accent,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: ClaudeColors.accent,
          onPrimary: ClaudeColors.onAccent,
          surface: c.surface,
          onSurface: c.textPrimary,
          onSurfaceVariant: c.textSecondary,
          outline: c.borderStrong,
          outlineVariant: c.border,
          surfaceContainerLowest: c.canvas,
          surfaceContainerLow: c.sidebar,
          surfaceContainer: c.surfaceSunken,
          surfaceTint: Colors.transparent,
          error: c.dangerMark,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      textTheme: ClaudeText.textTheme(
        c.textPrimary,
        c.textSecondary,
        c.textTertiary,
      ),

      // Sheets feel like a panel lifted off the page, not a system dialog.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        modalBarrierColor: Colors.black.withAlpha(isDark ? 140 : 64),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ClaudeRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClaudeRadius.lg),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: c.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textSecondary, size: 22),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClaudeColors.accent,
          foregroundColor: ClaudeColors.onAccent,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.textTertiary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClaudeRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          backgroundColor: c.surface,
          side: BorderSide(color: c.border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClaudeRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textSecondary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Sliders are all over the server settings page; keep them thin and
      // quiet rather than Material's fat default.
      sliderTheme: SliderThemeData(
        activeTrackColor: ClaudeColors.accent,
        inactiveTrackColor: c.surfaceSunken,
        thumbColor: ClaudeColors.accent,
        overlayColor: ClaudeColors.accent.withAlpha(24),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ClaudeColors.onAccent
              : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ClaudeColors.accent
              : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : c.borderStrong,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceSunken : const Color(0xFF2E2E2B),
        contentTextStyle: TextStyle(fontSize: 14, color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClaudeRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ClaudeColors.accent,
        linearTrackColor: c.surfaceSunken,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surfaceSunken : const Color(0xFF2E2E2B),
          borderRadius: BorderRadius.circular(ClaudeRadius.sm),
        ),
        textStyle: const TextStyle(fontSize: 12, color: Color(0xFFF5F4EF)),
      ),
      splashFactory: InkSparkle.splashFactory,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.borderStrong),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
      ),
    );
  }
}
