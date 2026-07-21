import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// در ویندوز/لینوکس/مک → ذخیره مستقیم در Downloads
/// در موبایل → null برمی‌گرداند تا sharePdf استفاده شود
Future<String?> saveFileToDownloads(Uint8List bytes, String filename) async {
  try {
    // موبایل: دیالوگ اشتراک‌گذاری مناسب‌تر است
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();

    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    debugPrint('Save error: $e');
    return null;
  }
}