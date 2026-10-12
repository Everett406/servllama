import 'package:flutter/material.dart';

/// Design tokens for the Claude-inspired visual language.
///
/// The look is built from four things, in order of how much they carry it:
/// warm neutrals (never pure grey), one brick-orange accent, generous
/// vertical rhythm, and radii that stay large everywhere. Getting the
/// neutrals warm matters most — a neutral grey with these same accents
/// reads as a generic Material app, not this one.
class ClaudeColors {
  const ClaudeColors._();

  // ── Light ────────────────────────────────────────────────────────────────
  /// Main chat canvas. Warm off-white, never #FFFFFF.
  static const canvas = Color(0xFFFAF9F5);

  /// Sidebar sits a half-step darker than the canvas so the seam is felt,
  /// not seen.
  static const sidebar = Color(0xFFF5F4EF);

  /// Raised cards, input fields, menus.
  static const surface = Color(0xFFFFFFFF);

  /// A step below surface — nested rows, hover fills.
  static const surfaceSunken = Color(0xFFF0EEE7);

  static const border = Color(0xFFE5E3DC);
  static const borderStrong = Color(0xFFD4D2CB);

  static const textPrimary = Color(0xFF141413);
  static const textSecondary = Color(0xFF6B6A65);
  static const textTertiary = Color(0xFF8A8984);

  // ── Dark ─────────────────────────────────────────────────────────────────
  static const canvasDark = Color(0xFF262624);
  static const sidebarDark = Color(0xFF1F1E1D);
  static const surfaceDark = Color(0xFF30302E);
  static const surfaceSunkenDark = Color(0xFF141413);

  static const borderDark = Color(0xFF3E3E3A);
  static const borderStrongDark = Color(0xFF52514C);

  static const textPrimaryDark = Color(0xFFF5F4EF);
  static const textSecondaryDark = Color(0xFFB4B3AD);
  static const textTertiaryDark = Color(0xFF8A8984);

  // ── Accent ───────────────────────────────────────────────────────────────
  /// The brick orange. Deliberately not a Material "tertiary container" —
  /// filled actions use this directly so they read as the one warm spot on
  /// a page full of warm neutrals.
  static const accent = Color(0xFFD97757);
  static const accentPressed = Color(0xFFC15F3C);
  static const accentSubtle = Color(0xFFF2E4DD);
  static const accentSubtleDark = Color(0xFF3A2C25);
  static const onAccent = Color(0xFFFFFFFF);

  // ── Status ───────────────────────────────────────────────────────────────
  static const ok = Color(0xFF0CA30C);
  static const okText = Color(0xFF0A7D0A);
  static const okTextDark = Color(0xFF6FE38A);

  static const warning = Color(0xFFFAB219);
  static const warningText = Color(0xFF8A5D00);
  static const warningTextDark = Color(0xFFF0C35C);

  static const danger = Color(0xFFD03B3B);
  static const dangerText = Color(0xFFB22B2B);
  static const dangerTextDark = Color(0xFFF08D8D);

  static const idle = Color(0xFF9AA3B4);
  static const idleDark = Color(0xFF6E7788);

  /// Engine identity. Kept blue/amber because that pair was validated for
  /// normal-vision *and* CVD separation — blue/violet failed deutan badly.
  /// The amber sits close to [accent] on purpose-adjacent hues, so the two
  /// are told apart by **form**, not colour: engine identity is only ever an
  /// outlined chip with a text label, never a filled orange shape.
  static const engineLlama = Color(0xFF3B6BF5);
  static const engineLlamaDark = Color(0xFF7DA2FF);
  static const engineMnn = Color(0xFFC2703A);
  static const engineMnnDark = Color(0xFFE0703A);
}

class ClaudeRadius {
  const ClaudeRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;

  /// Sheets and modal dialogs.
  static const sheet = 24.0;

  /// The composer. Nearly a pill — the composer reads as one object you
  /// address, not a form you fill in.
  static const composer = 28.0;
}

class ClaudeSpacing {
  const ClaudeSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Chat content never runs wider than this — long lines are unreadable.
  static const readingWidth = 768.0;

  /// Horizontal gutter for page content, scaled down on phones so the
  /// measure stays readable.
  static double gutter(double width) {
    if (width >= 1000) return xxl;
    if (width >= 600) return xl;
    return lg;
  }
}

class ClaudeMotion {
  const ClaudeMotion._();

  /// Short state changes (hover, press, colour).
  static const fast = Duration(milliseconds: 120);

  /// Entrances and larger layout moves.
  static const medium = Duration(milliseconds: 220);

  /// The one soft spring, used for sheets and the sidebar.
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

/// Typography.
///
/// The reference uses Styrene (grotesque) for body and Copernicus (serif) for
/// display. Neither is freely redistributable, so body falls back to the
/// platform grotesque and display to the platform serif — the pairing reads
/// the same at display sizes, which is where it is actually visible.
class ClaudeText {
  const ClaudeText._();

  static const _serif = 'serif';

  static TextTheme textTheme(Color primary, Color secondary, Color tertiary) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      String? family,
      Color? color,
    }) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        fontFamily: family,
        color: color ?? primary,
      );
    }

    return TextTheme(
      // Serif, tight — used for page titles and empty-state headlines.
      displaySmall: s(
        32,
        FontWeight.w500,
        height: 1.2,
        spacing: -0.6,
        family: _serif,
      ),
      headlineMedium: s(
        24,
        FontWeight.w500,
        height: 1.25,
        spacing: -0.4,
        family: _serif,
      ),
      headlineSmall: s(
        20,
        FontWeight.w500,
        height: 1.3,
        spacing: -0.2,
        family: _serif,
      ),
      titleLarge: s(17, FontWeight.w600, height: 1.35, spacing: -0.2),
      titleMedium: s(15, FontWeight.w600, height: 1.4, color: primary),
      titleSmall: s(13, FontWeight.w600, height: 1.4, color: secondary),

      bodyLarge: s(16, FontWeight.w400, height: 1.6, color: primary),
      bodyMedium: s(14, FontWeight.w400, height: 1.55, color: primary),
      bodySmall: s(13, FontWeight.w400, height: 1.5, color: secondary),

      labelLarge: s(14, FontWeight.w600, height: 1.2, color: primary),
      labelMedium: s(13, FontWeight.w500, height: 1.2, color: secondary),
      labelSmall: s(12, FontWeight.w500, height: 1.2, color: tertiary),
    );
  }
}
