import 'package:flutter/material.dart';

/// 全局主题：暖橙食欲风（暖橙 + 米色 + 深咖文字）
class AppTheme {
  static const primary = Color(0xFFE8743B); // 暖橙
  static const primaryDark = Color(0xFFC95A26);
  static const cream = Color(0xFFFFF8F0); // 米色背景
  static const cardBg = Color(0xFFFFFFFF);
  static const ink = Color(0xFF3E2C20); // 深咖文字
  static const inkLight = Color(0xFF8A7363);
  static const green = Color(0xFF4CAF50); // 达标
  static const red = Color(0xFFE53935); // 超标
  static const blue = Color(0xFF42A5F5); // 消耗
  static const amber = Color(0xFFFFB300);

  static ThemeData light({String? fontFamily}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: amber,
      surface: cream,
      onSurface: ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            color: ink, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, color: inkLight)),
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? primary
                    : inkLight)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8D9CB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8D9CB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(color: primary.withValues(alpha: 0.35)),
        labelStyle: const TextStyle(color: ink, fontSize: 13),
      ),
    );
  }
}
