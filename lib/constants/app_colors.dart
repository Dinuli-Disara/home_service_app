import 'package:flutter/material.dart';

class AppColors {
  // Core Brand Colors
  static const Color actionOrange = Color(0xFFF37021);
  static const Color trustBlue = Color(0xFF1B4E81);
  static const Color modernTeal = Color(0xFF008894);
  static const Color vividAzure = Color(0xFF136EB5);
  static const Color steelGray = Color(0xFF4D4D4D);
  static const Color cleanWhite = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Background & Surface
  static const Color background = cleanWhite;
  static const Color surface = Color(0xFFF8F9FA); // Slightly off-white
  static const Color card = cleanWhite;

  // Text Colors
  static const Color textPrimary = steelGray;
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textDisabled = Color(0xFFADB5BD);

  // Border & Divider
  static const Color border = Color(0xFFDEE2E6);
  static const Color divider = Color(0xFFE9ECEF);

  // States
  static const Color hover = Color(0xFFE9F5FF);
  static const Color selected = Color(0xFFD1E7FF);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [trustBlue, vividAzure],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient accentGradient = LinearGradient(
    colors: [actionOrange, Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}