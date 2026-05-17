import 'package:flutter/material.dart';

// 5位專家共識配色：Blaze Orange 主色 + 明亮兒童風格
class AppTheme {
  // 主色系
  static const Color primary = Color(0xFFFF6B35);   // Blaze Orange
  static const Color secondary = Color(0xFFFFD93D);  // Bright Yellow
  static const Color accent = Color(0xFFE94560);     // Hot Pink/Red
  static const Color success = Color(0xFF4ADE80);    // Green

  // 背景
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF16213E);
  static const Color surfaceLight = Color(0xFF0F3460);
  static const Color surfaceCard = Color(0xFF1A2540);

  // 文字
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textGold = Color(0xFFFFD700);

  // 狀態
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFBBF24);

  // 漸變
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFF050510)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF8C5A), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 陰影
  static List<BoxShadow> get glowShadow => [
    BoxShadow(color: primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6)),
  ];

  static List<BoxShadow> goldShadow([double opacity = 0.5]) => [
    BoxShadow(color: Color(0xFFFFD700).withOpacity(opacity), blurRadius: 15, spreadRadius: 2),
  ];

  // 主題
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: textPrimary, fontFamily: 'Roboto'),
      displayMedium: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: textPrimary, fontFamily: 'Roboto'),
      displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary, fontFamily: 'Roboto'),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Roboto'),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Roboto'),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimary, fontFamily: 'Roboto'),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary, fontFamily: 'Roboto'),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary, fontFamily: 'Roboto'),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Roboto'),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: CardTheme(
      color: surfaceCard,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
  );
}