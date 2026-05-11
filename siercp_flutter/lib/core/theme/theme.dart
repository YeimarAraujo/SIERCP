import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Marca - Más vibrante y profesional
  static const brand = Color(0xFF1E40AF); // Blue-800
  static const brand2 = Color(0xFF3B82F6); // Blue-500
  static const brand3 = Color(0xFF1E3A8A); // Blue-900
  static const brandLight = Color(0xFFDBEAFE); // Blue-100
  static const brandBg = Color(0x1A1E40AF);

  // Semánticos
  static const green = Color(0xFF00E676);
  static const greenBg = Color(0x1A00E676);
  static const red = Color(0xFFFF3B5C);
  static const redBg = Color(0x1AFF3B5C);
  static const amber = Color(0xFFFFAB00);
  static const amberBg = Color(0x1FFFAB00);
  static const cyan = Color(0xFF00D4FF);
  static const cyanBg = Color(0x1A00D4FF);
  static const blue = Color(0xFF2196F3);
  static const orange = Color(0xFFFF8A00);

  // Dark Mode — Fondos - Estilo Deep Navy
  static const darkBg = Color(0xFF020617); // Slate-950
  static const darkBg2 = Color(0xFF0F172A); // Slate-900
  static const darkBg3 = Color(0xFF1E293B); // Slate-800
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurface2 = Color(0xFF334155);
  static const darkCard = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);

  // Dark Mode — Texto
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFB0B8C4);
  static const darkTextTertiary = Color(0xFF717D8A);

  // Light Mode — Fondos
  static const lightBg = Color(0xFFF8FAFC); // Slate-50
  static const lightBg2 = Color(0xFFF1F5F9); // Slate-100
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF8FAFC);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E7F0);

  // Light Mode — Texto
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF334155);
  static const lightTextTertiary = Color(0xFF64748B);

  // Acento compartido
  static const accent = Color(0xFF8B7CF8);

  // Alias para compatibilidad legado
  static const bg = darkBg;
  static const bg2 = darkBg2;
  static const bg3 = darkBg3;
  static const card = darkCard;
  static const cardBorder = darkBorder;
  static const textPrimary = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textTertiary = darkTextTertiary;
}

// ─── Radios ────────────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
}

// ─── Sombras ───────────────────────────────────────────────────────────────────
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF1800AD).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];

  static List<BoxShadow> elevated(bool isDark) => isDark
      ? [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textP =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textS =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textT =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final fillColor = isDark ? AppColors.darkCard : AppColors.lightSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: AppColors.brand,
              secondary: AppColors.cyan,
              surface: surface,
              surfaceContainerHighest: surface2,
              error: AppColors.red,
              onPrimary: Colors.white,
              onSurface: textP,
              outline: border,
            )
          : ColorScheme.light(
              primary: AppColors.brand,
              secondary: AppColors.brandLight,
              surface: surface,
              surfaceContainerHighest: surface2,
              error: AppColors.red,
              onPrimary: Colors.white,
              onSurface: textP,
              outline: border,
            ),
      textTheme: GoogleFonts.dmSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: textP, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: textP, fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(
              color: textP, fontWeight: FontWeight.w700, fontSize: 24),
          headlineMedium: TextStyle(
              color: textP, fontWeight: FontWeight.w600, fontSize: 20),
          headlineSmall: TextStyle(
              color: textP, fontWeight: FontWeight.w600, fontSize: 18),
          titleLarge: TextStyle(
              color: textP, fontWeight: FontWeight.w600, fontSize: 16),
          titleMedium: TextStyle(
              color: textP, fontWeight: FontWeight.w500, fontSize: 14),
          titleSmall: TextStyle(
              color: textP, fontWeight: FontWeight.w500, fontSize: 13),
          bodyLarge: TextStyle(color: textP, fontSize: 15),
          bodyMedium: TextStyle(color: textS, fontSize: 13),
          bodySmall: TextStyle(color: textT, fontSize: 11),
          labelLarge: TextStyle(
              color: textP, fontWeight: FontWeight.w600, fontSize: 13),
          labelMedium: TextStyle(color: textS, fontSize: 11),
          labelSmall:
              TextStyle(color: textT, fontSize: 10, letterSpacing: 0.08),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textP, size: 22),
        titleTextStyle: GoogleFonts.dmSans(
          color: textP,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        labelStyle: TextStyle(color: textS, fontSize: 13),
        hintStyle: TextStyle(color: textT),
        prefixIconColor: textT,
        suffixIconColor: textT,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.02,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle:
              GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightBg2,
        selectedColor: AppColors.brand.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: textS, fontSize: 12),
        side: BorderSide(color: border, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border, width: 0.5),
        ),
        titleTextStyle: GoogleFonts.dmSans(
          color: textP,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          color: textS,
          fontSize: 13,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? AppColors.darkSurface2 : AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkBg2 : AppColors.lightSurface,
        indicatorColor: AppColors.brand.withValues(alpha: isDark ? 0.35 : 0.1),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            color:
                selected ? (isDark ? AppColors.cyan : AppColors.brand) : textT,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? AppColors.cyan : AppColors.brand)
                : textT.withValues(alpha: 0.7),
            size: 24,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : textT),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.brand
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
