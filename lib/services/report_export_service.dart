import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/persian_utils.dart';
import '../widgets/report_table_view.dart';
import '../utils/file_saver_stub.dart'
    if (dart.library.io) '../utils/file_saver_io.dart';

class ReportExportService {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  /// لود فونت فارسی — با fallback
  static Future<void> _loadFonts() async {
    if (_regularFont != null) return;

    // تلاش ۱: فایل محلی
    try {
      _regularFont = pw.Font.ttf(
          await rootBundle.load('assests/fonts/Vazirmatn-Regular.ttf'));
      _boldFont = pw.Font.ttf(
          await rootBundle.load('assests/fonts/Vazirmatn-Bold.ttf'));
      debugPrint('✅ فونت PDF جدول از assets لود شد');
      return;
    } catch (e) {
      debugPrint('⚠️ لود فونت محلی ناموفق: $e');
    }

    // تلاش ۲: وزیرمتن آنلاین
    try {
      _regularFont = await PdfGoogleFonts.vazirmatnRegular();
      _boldFont = await PdfGoogleFonts.vazirmatnBold();
      debugPrint('✅ فونت PDF جدول از Google Fonts لود شد');
    } catch (e) {
      debugPrint('❌ هیچ فونت فارسی لود نشد: $e');
    }
  }

  // ═══════════════ CSV ═══════════════

  static String generateCsv(List<TableRowData> rows) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // BOM برای اکسل
    buffer.writeln('ردیف,تگ,مقدار,واحد,تاریخ شمسی,وضعیت');

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      buffer.writeln(
        '${PersianUtils.toPersian(i + 1)},'
        '"${row.tag}",'
        '"${PersianUtils.formatNumber(row.value)}",'
        '"${row.unit}",'
        '"${PersianUtils.formatDateTime(row.timestamp)}",'
        '"${row.isAlarm ? 'آلارم' : 'عادی'}"',
      );
    }
    return buffer.toString();
  }

  /// ذخیره CSV — دسکتاپ: فایل / وب: کپی در کلیپ‌بورد
  static Future<String?> saveCsv(List<TableRowData> rows) async {
    final csv = generateCsv(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final filename = 'table_report_${DateTime.now().millisecondsSinceEpoch}.csv';

    final path = await saveFileToDownloads(bytes, filename);
    if (path != null) return path;

    await Clipboard.setData(ClipboardData(text: csv));
    return null; // یعنی در کلیپ‌بورد کپی شد
  }

  // ═══════════════ PDF ═══════════════

  static Future<Uint8List> generatePdf(
    List<TableRowData> rows, {
    String title = 'گزارش داده‌های SCADA',
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    const rowsPerPage = 28;
    final totalPages = (rows.length / rowsPerPage).ceil();

    for (var page = 0; page < totalPages; page++) {
      final startIdx = page * rowsPerPage;
      final endIdx = (startIdx + rowsPerPage).clamp(0, rows.length);
      final pageRows = rows.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: _regularFont != null
              ? pw.ThemeData.withFont(
                  base: _regularFont!, bold: _boldFont ?? _regularFont)
              : null,
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── هدر ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E293B'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'صفحه ${PersianUtils.toPersian(page + 1)} از ${PersianUtils.toPersian(totalPages)}',
                        style: pw.TextStyle(
                            font: _regularFont, fontSize: 9, color: PdfColors.grey400),
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            title,
                            style: pw.TextStyle(
                                font: _boldFont, fontSize: 16, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'تاریخ تولید: ${PersianUtils.formatDateTime(DateTime.now())}   |   '
                            '${PersianUtils.toPersian(rows.length)} ردیف',
                            style: pw.TextStyle(
                                font: _regularFont, fontSize: 8, color: PdfColors.grey400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // ── جدول ──
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(35),
                      1: pw.FlexColumnWidth(3),
                      2: pw.FlexColumnWidth(2),
                      3: pw.FixedColumnWidth(45),
                      4: pw.FlexColumnWidth(3),
                      5: pw.FixedColumnWidth(55),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#334155')),
                        children: ['#', 'تگ', 'مقدار', 'واحد', 'تاریخ شمسی', 'وضعیت']
                            .map((h) => _cell(h, bold: true, textColor: PdfColors.white))
                            .toList(),
                      ),
                      ...pageRows.asMap().entries.map((entry) {
                        final idx = startIdx + entry.key;
                        final row = entry.value;
                        final bgColor = row.isAlarm
                            ? PdfColor.fromHex('#FEE2E2')
                            : idx.isEven
                                ? PdfColor.fromHex('#F8FAFC')
                                : PdfColors.white;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: bgColor),
                          children: [
                            _cell(PersianUtils.toPersian(idx + 1)),
                            _cell(row.tag),
                            _cell(
                              PersianUtils.formatNumber(row.value),
                              textColor: row.isAlarm ? PdfColors.red : PdfColors.blue800,
                              bold: true,
                            ),
                            _cell(row.unit),
                            _cell(PersianUtils.formatDateTime(row.timestamp)),
                            _cell(
                              row.isAlarm ? 'آلارم' : 'عادی',
                              textColor: row.isAlarm ? PdfColors.red : PdfColors.green,
                              bold: row.isAlarm,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                // ── فوتر ──
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('سیستم مانیتورینگ SCADA',
                        style: pw.TextStyle(
                            font: _regularFont, fontSize: 8, color: PdfColors.grey)),
                    pw.Text('مجموع: ${PersianUtils.toPersian(rows.length)} ردیف',
                        style: pw.TextStyle(
                            font: _regularFont, fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  /// چاپ — در ویندوز دیالوگ چاپ بومی باز می‌شود
  static Future<void> printTable(List<TableRowData> rows, {String? title}) async {
    final bytes = await generatePdf(rows, title: title ?? 'گزارش داده‌های SCADA');
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// ذخیره PDF — دسکتاپ: Downloads / بقیه: دیالوگ اشتراک
  static Future<String?> savePdf(List<TableRowData> rows, {String? title}) async {
    final bytes = await generatePdf(rows, title: title ?? 'گزارش داده‌های SCADA');
    final filename = 'table_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final path = await saveFileToDownloads(bytes, filename);
    if (path != null) return path;

    await Printing.sharePdf(bytes: bytes, filename: filename);
    return null;
  }

  // ── سازگاری با کدهای قبلی report_screen ──
  static Future<void> printPdf(List<TableRowData> rows) => printTable(rows);
  static Future<void> sharePdf(List<TableRowData> rows) async => savePdf(rows);

  // ─── سلول جدول PDF ───
  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor textColor = PdfColors.grey800,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? (_boldFont ?? _regularFont) : _regularFont,
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }
}

