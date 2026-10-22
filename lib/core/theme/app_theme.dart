import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Hệ thống theme đồng bộ và hiện đại: Tông Xanh Sapphire Hoàng Gia & Xanh Cyan Công Nghệ
class AppTheme {
  static const primaryColor = Color(0xFF2563EB); // Royal Sapphire Blue rực rỡ, hiện đại
  static const primaryDark = Color(0xFF1E3A8A); // Deep Navy sang trọng
  static const secondaryColor = Color(0xFF0EA5E9); // Tech Sky / Cyan tươi sáng, hài hòa
  static const tertiaryColor = Color(0xFF6366F1); // Modern Indigo thanh lịch
  static const accentColor = Color(0xFF38BDF8); // Electric Sky
  static const successColor = Color(0xFF10B981); // Emerald Green
  static const warningColor = Color(0xFFF59E0B); // Amber Yellow (cho cảnh báo, chờ duyệt)
  static const errorColor = Color(0xFFEF4444); // Crimson Red
  static const seed = Color(0xFF2563EB);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEFF6FF), // Nền xanh băng nhạt thanh khiết
      onPrimaryContainer: const Color(0xFF1D4ED8), // Chữ xanh sapphire tương phản cao
      secondary: secondaryColor,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0F2FE), // Nền xanh sky nhạt
      onSecondaryContainer: const Color(0xFF0369A1), // Chữ xanh sky đậm nét
      tertiary: tertiaryColor,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFEEF2FF),
      onTertiaryContainer: const Color(0xFF3730A3),
      surface: const Color(0xFFF8FAFC), // Slate 50 siêu sạch, hiện đại
      onSurface: const Color(0xFF0F172A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE2E8F0),
      outlineVariant: const Color(0xFFE2E8F0),
      error: errorColor,
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA), // Xanh sapphire sáng cho dark mode
      onPrimary: const Color(0xFF0F172A),
      primaryContainer: const Color(0xFF1E3A8A),
      onPrimaryContainer: const Color(0xFFDBEAFE),
      secondary: const Color(0xFF38BDF8),
      onSecondary: const Color(0xFF082F49),
      secondaryContainer: const Color(0xFF075985),
      onSecondaryContainer: const Color(0xFFE0F2FE),
      tertiary: const Color(0xFF818CF8),
      surface: const Color(0xFF0B1120),
      onSurface: const Color(0xFFF1F5F9),
      surfaceContainerLowest: const Color(0xFF070B14),
      surfaceContainerLow: const Color(0xFF0F172A),
      surfaceContainer: const Color(0xFF1E293B),
      surfaceContainerHigh: const Color(0xFF334155),
      outlineVariant: const Color(0xFF334155),
      error: const Color(0xFFF87171),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 0.5,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 50),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: buttonShape,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return const IconThemeData(color: Color(0xFF64748B), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
            color: selected ? scheme.primary : const Color(0xFF64748B),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.primary,
        checkmarkColor: Colors.white,
        backgroundColor: scheme.surfaceContainerLow,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    );
  }
}

