import 'package:flutter_scada/utils/shamsi_date/lib/shamsi_date.dart';

class PersianUtils {
  static const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  
  static const monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

static const weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  static String toPersian(dynamic num) {
    return num.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? persianDigits[i] : c;
    }).join();
  }

  static String formatDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${toPersian(j.year)}/${toPersian(j.month.toString().padLeft(2, '0'))}/${toPersian(j.day.toString().padLeft(2, '0'))}';
  }

  static String formatDateTime(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '${toPersian(j.year)}/${toPersian(j.month.toString().padLeft(2, '0'))}/${toPersian(j.day.toString().padLeft(2, '0'))} ${toPersian(h)}:${toPersian(m)}:${toPersian(s)}';
  }

  static String formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${toPersian(h)}:${toPersian(m)}';
  }

  static String formatShortDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${toPersian(j.month)}/${toPersian(j.day)}';
  }
  static String formatFull(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${toPersian(j.day)} ${monthNames[j.month - 1]} ${toPersian(j.year)}';
  }

  static String formatNumber(double num, {int decimals = 2}) {
    return toPersian(num.toStringAsFixed(decimals));
  }

  static String formatInt(int num) {
    // اضافه کردن جداکننده هزارگان
    final str = num.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('٬');
      }
      buffer.write(persianDigits[int.parse(str[i])]);
    }
    return buffer.toString();
  }

  
 static String toPersianDigits(dynamic number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    String result = number.toString();
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  // تبدیل اعداد فارسی به انگلیسی
  static String toEnglishDigits(String text) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    
    String result = text;
    for (int i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], english[i]);
    }
    return result;
  }


  // نام روزهای هفته
  static const List<String> weekDayNames = [
    'شنبه', 'یکشنبه', 'دوشنبه', 
    'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه',
  ];

  static const List<String> weekDayNamesShort = [
    'ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج',
  ];

  // تبدیل میلادی به شمسی
  static Jalali toJalali(DateTime date) {
    return Jalali.fromDateTime(date);
  }

  // تبدیل شمسی به میلادی
  static DateTime toGregorian(Jalali jalali) {
    return jalali.toDateTime();
  }

  // فرمت تاریخ شمسی کامل: ۱۵ مهر ۱۴۰۳
  static String formatJalali(DateTime date) {
    final j = toJalali(date);
    return '${toPersianDigits(j.day)} ${monthNames[j.month - 1]} ${toPersianDigits(j.year)}';
  }

  // فرمت تاریخ شمسی عددی: ۱۴۰۳/۰۷/۱۵
  static String formatJalaliNumeric(DateTime date) {
    final j = toJalali(date);
    final month = j.month.toString().padLeft(2, '0');
    final day = j.day.toString().padLeft(2, '0');
    return '${toPersianDigits(j.year)}/${toPersianDigits(month)}/${toPersianDigits(day)}';
  }

  // فرمت تاریخ و ساعت شمسی
  static String formatJalaliDateTime(DateTime date) {
    final j = toJalali(date);
    final month = j.month.toString().padLeft(2, '0');
    final day = j.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${toPersianDigits(j.year)}/${toPersianDigits(month)}/${toPersianDigits(day)} - ${toPersianDigits(hour)}:${toPersianDigits(minute)}';
  }

  // فرمت عدد با اعشار فارسی
  static String formatPersianNumber(double number, {int decimals = 2}) {
    return toPersianDigits(number.toStringAsFixed(decimals));
  }

  // تعداد روزهای ماه شمسی
  static int getMonthDays(int year, int month) {
    return Jalali(year, month).monthLength;
  }

  // روز هفته برای تاریخ شمسی (۰=شنبه، ۶=جمعه)
  static int getWeekDay(Jalali jalali) {
    // shamsi_date: شنبه=1 ... جمعه=7
    return jalali.weekDay - 1;
  }

  // آیا سال کبیسه است؟
  static bool isLeapYear(int year) {
    return Jalali(year).isLeapYear();
  }

  // تاریخ شمسی امروز
  static Jalali today() {
    return Jalali.now();
  }
}