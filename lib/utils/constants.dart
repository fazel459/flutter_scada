import 'package:flutter/material.dart';

class Constants {
  static const List<String> units = [
    '',
    '°C',
    '°F',
    'K',
    'Pa',
    'kPa',
    'MPa',
    'bar',
    'psi',
    'atm',
    '%',
    'L',
    'm³',
    'gal',
    'm/s',
    'km/h',
    'mph',
    'A',
    'V',
    'W',
    'kW',
    'Hz',
    'RPM',
    'm',
    'mm',
    'cm',
    'kg',
    'ton',
    'lb',
    'L/min',
    'm³/h',
    'GPM',
  ];

  static const List<Map<String, String>> themes = [
    {
      'id': 'dark',
      'label': 'Dark',
      'bg': '#0F172A',
      'text': '#E2E8F0',
      'panel': '#1E293B',
      'accent': '#3B82F6',
    },
    {
      'id': 'midnight',
      'label': 'Midnight',
      'bg': '#1A1A2E',
      'text': '#EEEEEE',
      'panel': '#16213E',
      'accent': '#E94560',
    },
    {
      'id': 'light',
      'label': 'Light',
      'bg': '#F8FAFC',
      'text': '#1E293B',
      'panel': '#FFFFFF',
      'accent': '#2563EB',
    },
    {
      'id': 'industrial',
      'label': 'Industrial',
      'bg': '#2D3436',
      'text': '#DFE6E9',
      'panel': '#353B48',
      'accent': '#00B894',
    },
    {
      'id': 'ocean',
      'label': 'Ocean',
      'bg': '#0C2461',
      'text': '#82CCDD',
      'panel': '#1E3799',
      'accent': '#78E08F',
    },
  ];

  static Map<String, String> getTheme(String id) {
    return themes.firstWhere(
      (t) => t['id'] == id,
      orElse: () => themes[0],
    );
  }
}

/// Color parsing utility - converts hex string to Flutter Color
Color colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length == 6) {
    return Color(int.parse('FF$h', radix: 16));
  } else if (h.length == 8) {
    return Color(int.parse(h, radix: 16));
  }
  return const Color(0xFFEF4444);
}

String colorToHex(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
