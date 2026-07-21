import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;   // ← جدید
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/persian_utils.dart';
import '../utils/file_saver_stub.dart'                     // ← جدید
    if (dart.library.io) '../utils/file_saver_io.dart';

/// مدل آلارم
class AlarmData {
  final int id;
  final String tag;
  final String alarmType;
  final double value;
  final double threshold;
  final String message;
  final bool acknowledged;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  AlarmData({
    required this.id,
    required this.tag,
    required this.alarmType,
    required this.value,
    required this.threshold,
    required this.message,
    required this.acknowledged,
    required this.createdAt,
    this.acknowledgedAt,
  });

  String get alarmTypeLabel {
    switch (alarmType) {
      case 'high': return 'بالا';
      case 'low': return 'پایین';
      case 'high_high': return 'بالای بالا';
      case 'low_low': return 'پایین پایین';
      default: return alarmType;
    }
  }

  Color get severityColor {
    switch (alarmType) {
      case 'high_high':
      case 'low_low':
        return Colors.red;
      case 'high':
      case 'low':
        return Colors.orange;
      default:
        return Colors.yellow;
    }
  }

  int get severityLevel {
    switch (alarmType) {
      case 'high_high':
      case 'low_low':
        return 3;
      case 'high':
      case 'low':
        return 2;
      default:
        return 1;
    }
  }
}

class ReportAlarmsView extends StatefulWidget {
  final List<AlarmData> alarms;
  final Function(int alarmId)? onAcknowledge;
  final Future<void> Function()? onRefresh;

  const ReportAlarmsView({
    super.key,
    required this.alarms,
    this.onAcknowledge,
    this.onRefresh,
  });

  @override
  State<ReportAlarmsView> createState() => _ReportAlarmsViewState();
}

class _ReportAlarmsViewState extends State<ReportAlarmsView> {
  List<AlarmData> _filteredAlarms = [];
  
  // فیلترها
  String _searchQuery = '';
  String? _selectedType;
  bool? _acknowledgedFilter;
  int? _severityFilter;
  
  // مرتب‌سازی
  String _sortBy = 'time';
  bool _sortAsc = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  @override
  void didUpdateWidget(ReportAlarmsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarms != widget.alarms) {
      _applyFilters();
    }
  }

  void _applyFilters() {
    _filteredAlarms = widget.alarms.where((a) {
      if (_searchQuery.isNotEmpty && !a.tag.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedType != null && a.alarmType != _selectedType) return false;
      if (_acknowledgedFilter != null && a.acknowledged != _acknowledgedFilter) return false;
      if (_severityFilter != null && a.severityLevel != _severityFilter) return false;
      return true;
    }).toList();

    // مرتب‌سازی
    _filteredAlarms.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'tag':
          cmp = a.tag.compareTo(b.tag);
          break;
        case 'type':
          cmp = a.alarmType.compareTo(b.alarmType);
          break;
        case 'severity':
          cmp = a.severityLevel.compareTo(b.severityLevel);
          break;
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });

    setState(() {});
  }

  // آمار
  int get _totalCount => widget.alarms.length;
  int get _activeCount => widget.alarms.where((a) => !a.acknowledged).length;
  int get _acknowledgedCount => widget.alarms.where((a) => a.acknowledged).length;
  int get _criticalCount => widget.alarms.where((a) => a.severityLevel == 3 && !a.acknowledged).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // نوار آمار
        _buildStatsBar(),
        
        // نوار فیلتر
        _buildFilterBar(),
        
        // لیست آلارم‌ها
                Expanded(
          child: Stack(
            children: [
              widget.alarms.isEmpty
                  ? _buildEmptyState()
                  : _filteredAlarms.isEmpty
                      ? const Center(
                          child: Text('نتیجه‌ای یافت نشد',
                              style: TextStyle(
                                  fontFamily: 'Vazirmatn', color: Colors.white38)))
                      : RefreshIndicator(
                          onRefresh: widget.onRefresh ?? () async {},
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAlarms.length,
                            itemBuilder: (context, index) =>
                                _buildAlarmCard(_filteredAlarms[index]),
                          ),
                        ),
              if (_isExporting)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('در حال آماده‌سازی PDF...',
                            style: TextStyle(
                                fontFamily: 'Vazirmatn', color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
// ═══════════════════════════════════════════════════════════
  //  چاپ و خروجی PDF آلارم‌ها — بدون File، با فونت فارسی
  // ═══════════════════════════════════════════════════════════

  pw.Font? _pdfRegular;
  pw.Font? _pdfBold;
  bool _isExporting = false;

  Future<void> _loadAlarmPdfFonts() async {
    if (_pdfRegular != null) return;
    try {
      _pdfRegular = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
      _pdfBold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
      debugPrint('✅ فونت PDF آلارم از assets لود شد');
      return;
    } catch (e) {
      debugPrint('⚠️ فونت محلی آلارم لود نشد: $e');
    }
    try {
      _pdfRegular = await PdfGoogleFonts.vazirmatnRegular();
      _pdfBold = await PdfGoogleFonts.vazirmatnBold();
      debugPrint('✅ فونت PDF آلارم از Google Fonts لود شد');
    } catch (e) {
      debugPrint('❌ هیچ فونت فارسی لود نشد: $e');
    }
  }

  Future<Uint8List?> _buildAlarmPdfBytes() async {
    if (_filteredAlarms.isEmpty) return null;
    await _loadAlarmPdfFonts();

    final pdf = pw.Document();
    const rowsPerPage = 22;
    final totalPages = (_filteredAlarms.length / rowsPerPage).ceil();
    final now = DateTime.now();

    for (var page = 0; page < totalPages; page++) {
      final start = page * rowsPerPage;
      final end = (start + rowsPerPage).clamp(0, _filteredAlarms.length);
      final pageAlarms = _filteredAlarms.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: _pdfRegular != null
              ? pw.ThemeData.withFont(
                  base: _pdfRegular!, bold: _pdfBold ?? _pdfRegular)
              : null,
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfHeader(now, page, totalPages),
                pw.SizedBox(height: 10),
                _pdfStatsStrip(),
                pw.SizedBox(height: 12),
                pw.Expanded(child: _pdfTable(pageAlarms, start)),
                _pdfFooter(),
              ],
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  // ─── هدر PDF با راهنمای شدت ───
  pw.Widget _pdfHeader(DateTime now, int page, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1E293B'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'صفحه ${PersianUtils.toPersian(page + 1)} از ${PersianUtils.toPersian(totalPages)}',
                style: pw.TextStyle(
                    font: _pdfRegular, fontSize: 9, color: PdfColors.grey400),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  _pdfLegendDot('#EF4444', 'بحرانی'),
                  pw.SizedBox(width: 10),
                  _pdfLegendDot('#F59E0B', 'هشدار'),
                  pw.SizedBox(width: 10),
                  _pdfLegendDot('#22C55E', 'تأیید شده'),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'گزارش آلارم‌ها',
                style: pw.TextStyle(
                    font: _pdfBold, fontSize: 16, color: PdfColors.white),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'تولید: ${PersianUtils.formatDateTime(now)}   |   '
                '${PersianUtils.toPersian(_filteredAlarms.length)} آلارم',
                style: pw.TextStyle(
                    font: _pdfRegular, fontSize: 8, color: PdfColors.grey400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfLegendDot(String hex, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 7,
          height: 7,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex(hex),
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 3),
        pw.Text(
          label,
          style: pw.TextStyle(
              font: _pdfRegular, fontSize: 8, color: PdfColors.grey300),
        ),
      ],
    );
  }

  // ─── نوار آمار چهارگانه ───
  pw.Widget _pdfStatsStrip() {
    return pw.Row(
      children: [
        _pdfStatBox('کل آلارم‌ها', PersianUtils.toPersian(_totalCount),
            PdfColors.blue600, PdfColors.blue50),
        pw.SizedBox(width: 8),
        _pdfStatBox('فعال', PersianUtils.toPersian(_activeCount),
            PdfColors.red600, PdfColors.red50),
        pw.SizedBox(width: 8),
        _pdfStatBox('تأیید شده', PersianUtils.toPersian(_acknowledgedCount),
            PdfColors.green600, PdfColors.green50),
        pw.SizedBox(width: 8),
        _pdfStatBox('بحرانی', PersianUtils.toPersian(_criticalCount),
            PdfColors.orange600, PdfColors.orange50),
      ],
    );
  }

  pw.Widget _pdfStatBox(
      String label, String value, PdfColor main, PdfColor light) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: light,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: main, width: 0.6),
        ),
        child: pw.Column(
          children: [
            pw.Text(label,
                style: pw.TextStyle(font: _pdfRegular, fontSize: 8, color: main)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    font: _pdfBold ?? _pdfRegular,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: main)),
          ],
        ),
      ),
    );
  }

  // ─── جدول آلارم‌ها با رنگ‌بندی شدت ───
  pw.Widget _pdfTable(List<AlarmData> alarms, int startIndex) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.5),
        6: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#334155')),
          children: ['#', 'تگ', 'نوع آلارم', 'مقدار', 'حد مجاز', 'وضعیت', 'تاریخ شمسی']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                          font: _pdfBold, fontSize: 10, color: PdfColors.white),
                      textAlign: pw.TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        ...alarms.asMap().entries.map((entry) {
          final idx = startIndex + entry.key;
          final alarm = entry.value;

          // پس‌زمینه بر اساس شدت و وضعیت
          final PdfColor bg;
          if (!alarm.acknowledged && alarm.severityLevel == 3) {
            bg = PdfColors.red100;      // بحرانی فعال
          } else if (!alarm.acknowledged) {
            bg = PdfColors.orange50;    // هشدار فعال
          } else {
            bg = idx.isEven ? PdfColors.grey50 : PdfColors.white;
          }

          final sevColor = alarm.severityLevel == 3
              ? PdfColors.red700
              : PdfColors.orange800;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _alarmCell(PersianUtils.toPersian(idx + 1)),
              _alarmCell(alarm.tag, bold: true),
              _alarmCell(alarm.alarmTypeLabel, color: sevColor),
              _alarmCell(
                PersianUtils.formatNumber(alarm.value),
                color: sevColor,
                bold: true,
              ),
              _alarmCell(PersianUtils.formatNumber(alarm.threshold)),
              _alarmCell(
                alarm.acknowledged ? 'تأیید شده' : 'فعال',
                color: alarm.acknowledged ? PdfColors.green700 : PdfColors.red700,
                bold: !alarm.acknowledged,
              ),
              _alarmCell(PersianUtils.formatDateTime(alarm.createdAt)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _alarmCell(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? (_pdfBold ?? _pdfRegular) : _pdfRegular,
          fontSize: 9,
          color: color ?? PdfColors.grey800,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _pdfFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'سیستم مانیتورینگ SCADA',
              style: pw.TextStyle(
                  font: _pdfRegular, fontSize: 8, color: PdfColors.grey),
            ),
            pw.Text(
              'مجموع: ${PersianUtils.toPersian(_filteredAlarms.length)} آلارم',
              style: pw.TextStyle(
                  font: _pdfRegular, fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // ─── اکشن‌ها ───

  Widget _actionButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool showSpinner = false,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11),
      child: InkWell(
        onTap: _isExporting ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
          child: showSpinner
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                )
              : Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  /// چاپ — در ویندوز دیالوگ چاپ بومی باز می‌شود
  Future<void> _printAlarms() async {
    if (_filteredAlarms.isEmpty) {
      _showExportMsg('آلارمی برای چاپ وجود ندارد', error: true);
      return;
    }
    try {
      final bytes = await _buildAlarmPdfBytes();
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showExportMsg('خطا در چاپ: $e', error: true);
    }
  }

  /// PDF — دسکتاپ: ذخیره در Downloads / وب و موبایل: دیالوگ اشتراک
  Future<void> _exportAlarmPdf() async {
    if (_filteredAlarms.isEmpty) {
      _showExportMsg('آلارمی برای خروجی وجود ندارد', error: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildAlarmPdfBytes();
      if (bytes == null) return;

      final filename = 'alarms_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await saveFileToDownloads(bytes, filename);

      if (path != null) {
        _showExportMsg('PDF آلارم‌ها ذخیره شد:\n$path');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        _showExportMsg('PDF آماده ارسال شد');
      }
    } catch (e) {
      _showExportMsg('خطا در ایجاد PDF: $e', error: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportMsg(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          _buildStatChip('کل', _totalCount, Colors.blue),
          const SizedBox(width: 12),
          _buildStatChip('فعال', _activeCount, Colors.red, pulse: _activeCount > 0),
          const SizedBox(width: 12),
          _buildStatChip('تأیید شده', _acknowledgedCount, Colors.green),
          const SizedBox(width: 12),
          _buildStatChip('بحرانی', _criticalCount, Colors.deepOrange, pulse: _criticalCount > 0),

          const Spacer(),
          
          // Export
                   // ── نشانگر زنده محدوده خروجی ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_filteredAlarms.length),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'خروجی: ${PersianUtils.toPersian(_filteredAlarms.length)} آلارم فیلترشده',
                style: const TextStyle(
                    fontFamily: 'Vazirmatn', fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── چاپ و PDF ──
          _actionButton(Icons.print, 'چاپ آلارم‌ها', _printAlarms),
          const SizedBox(width: 6),
          _actionButton(
            Icons.picture_as_pdf,
            'خروجی PDF',
            _exportAlarmPdf,
            showSpinner: _isExporting,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color, {bool pulse = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            _PulsingDot(color: color)
          else
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            PersianUtils.toPersian(count),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          // جستجو
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'جستجو...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // فیلتر نوع
          _buildDropdownFilter(
            value: _selectedType,
            hint: 'نوع آلارم',
            items: [
              const DropdownMenuItem(value: null, child: Text('همه')),
              const DropdownMenuItem(value: 'high', child: Text('بالا')),
              const DropdownMenuItem(value: 'low', child: Text('پایین')),
              const DropdownMenuItem(value: 'high_high', child: Text('بحرانی بالا')),
              const DropdownMenuItem(value: 'low_low', child: Text('بحرانی پایین')),
            ],
            onChanged: (v) {
              _selectedType = v;
              _applyFilters();
            },
          ),
          
          const SizedBox(width: 8),
          
          // فیلتر وضعیت
          _buildDropdownFilter(
            value: _acknowledgedFilter,
            hint: 'وضعیت',
            items: [
              const DropdownMenuItem(value: null, child: Text('همه')),
              const DropdownMenuItem(value: false, child: Text('فعال')),
              const DropdownMenuItem(value: true, child: Text('تأیید شده')),
            ],
            onChanged: (v) {
              _acknowledgedFilter = v;
              _applyFilters();
            },
          ),
          
          const SizedBox(width: 8),
          
          // مرتب‌سازی
          _buildDropdownFilter(
            value: _sortBy,
            hint: 'مرتب‌سازی',
            items: [
              const DropdownMenuItem(value: 'time', child: Text('زمان')),
              const DropdownMenuItem(value: 'tag', child: Text('تگ')),
              const DropdownMenuItem(value: 'severity', child: Text('شدت')),
            ],
            onChanged: (v) {
              _sortBy = v ?? 'time';
              _applyFilters();
            },
          ),
          
          IconButton(
            onPressed: () {
              _sortAsc = !_sortAsc;
              _applyFilters();
            },
            icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          ),
          const SizedBox(height: 16),
          const Text('هیچ آلارمی وجود ندارد', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('همه چیز عادی است!', style: TextStyle(color: Colors.green, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(AlarmData alarm) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: alarm.acknowledged ? Colors.green.withValues(alpha: 0.3) : alarm.severityColor.withValues(alpha: 0.5),
          width: alarm.acknowledged ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showAlarmDetails(alarm),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // آیکون شدت
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: alarm.severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  alarm.acknowledged ? Icons.check_circle : Icons.warning,
                  color: alarm.acknowledged ? Colors.green : alarm.severityColor,
                  size: 22,
                ),
              ),
              
              const SizedBox(width: 14),
              
              // اطلاعات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          alarm.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: alarm.severityColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            alarm.alarmTypeLabel,
                            style: TextStyle(color: alarm.severityColor, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm.message,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'مقدار: ${PersianUtils.formatNumber(alarm.value)}',
                          style: TextStyle(color: alarm.severityColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.flag, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'حد: ${PersianUtils.formatNumber(alarm.threshold)}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // زمان و اکشن
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PersianUtils.formatDateTime(alarm.createdAt),
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  if (!alarm.acknowledged)
                    ElevatedButton(
                      onPressed: () => widget.onAcknowledge?.call(alarm.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('تأیید', style: TextStyle(fontSize: 10)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text('تأیید شده', style: TextStyle(color: Colors.green, fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlarmDetails(AlarmData alarm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: alarm.severityColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(alarm.tag, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155)),
            _detailRow('پیام', alarm.message),
            _detailRow('نوع آلارم', alarm.alarmTypeLabel),
            _detailRow('مقدار', PersianUtils.formatNumber(alarm.value)),
            _detailRow('حد مجاز', PersianUtils.formatNumber(alarm.threshold)),
            _detailRow('زمان ایجاد', PersianUtils.formatDateTime(alarm.createdAt)),
            _detailRow('وضعیت', alarm.acknowledged ? 'تأیید شده' : 'فعال'),
            if (alarm.acknowledgedAt != null)
              _detailRow('زمان تأیید', PersianUtils.formatDateTime(alarm.acknowledgedAt!)),
            const SizedBox(height: 16),
            if (!alarm.acknowledged)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onAcknowledge?.call(alarm.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تأیید آلارم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

 

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// نقطه چشمک‌زن
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 4 + _controller.value * 4)],
        ),
      ),
    );
  }
}
