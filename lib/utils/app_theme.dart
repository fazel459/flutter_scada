import 'package:flutter/material.dart';

class AppFonts {
  static const String vazir = 'Vazirmatn';

  // استایل‌های آماده
  static TextStyle heading({double size = 18, Color color = Colors.white}) {
    return TextStyle(
      fontFamily: vazir,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }
  static const TextStyle persianHeading1 = TextStyle(
    fontFamily: vazir,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  
  static const TextStyle persianHeading2 = TextStyle(
    fontFamily: vazir,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  
  static const TextStyle persianHeading3 = TextStyle(
    fontFamily: vazir,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static const TextStyle persianBodyLarge = TextStyle(
    fontFamily: vazir,
    fontSize: 14,
    color: Colors.white70,
  );
  
  static const TextStyle persianBodyMedium = TextStyle(
    fontFamily: vazir,
    fontSize: 12,
    color: Colors.white70,
  );
  
  static const TextStyle persianBodySmall = TextStyle(
    fontFamily: vazir,
    fontSize: 10,
    color: Color(0xFF64748B),
  );
  
  static const TextStyle persianButtonText = TextStyle(
    fontFamily: vazir,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  static TextStyle body({double size = 13, Color color = Colors.white}) {
    return TextStyle(
      fontFamily: vazir,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  static TextStyle label({double size = 11, Color color = const Color(0xFF94A3B8)}) {
    return TextStyle(
      fontFamily: vazir,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  // برای اعداد - وزن متوسط
  static TextStyle number({double size = 12, Color color = const Color(0xFF3B82F6)}) {
    return TextStyle(
      fontFamily: vazir,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }
}

class AppTheme {
  // تم تیره SCADA با فونت فارسی
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      
      // فونت پیش‌فرض کل اپلیکیشن
      fontFamily: AppFonts.vazir,
      
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.vazir,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppFonts.vazir, fontSize: 28, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: AppFonts.vazir, fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontFamily: AppFonts.vazir, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: AppFonts.vazir, fontSize: 14),
        bodyMedium: TextStyle(fontFamily: AppFonts.vazir, fontSize: 13),
        bodySmall: TextStyle(fontFamily: AppFonts.vazir, fontSize: 11),
        labelSmall: TextStyle(fontFamily: AppFonts.vazir, fontSize: 10),
      ),
      
      // فونت دکمه‌ها
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: AppFonts.vazir,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // فونت منوها
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(fontFamily: AppFonts.vazir, fontSize: 12),
      ),
    );
  }
}
