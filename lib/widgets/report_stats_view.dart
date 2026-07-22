import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/persian_utils.dart';
import '../utils/file_saver_stub.dart'
    if (dart.library.io) '../utils/file_saver_io.dart';

/// مدل آمار یک سری داده
class SeriesStats {
  final String tag;
  final String unit;
  final List<double> values;
  final List<DateTime> timestamps;

  SeriesStats({
    required this.tag,
    required this.unit,
    required this.values,
    required this.timestamps,
  });

  int get count => values.length;
  double get sum => values.fold(0.0, (a, b) => a + b);
  double get avg => count > 0 ? sum / count : 0;
  double get min => values.isEmpty ? 0 : values.reduce(math.min);
  double get max => values.isEmpty ? 0 : values.reduce(math.max);
  double get range => max - min;

  DateTime? get minTime {
    if (values.isEmpty) return null;
    final minIdx = values.indexOf(min);
    return timestamps[minIdx];
  }

  DateTime? get maxTime {
    if (values.isEmpty) return null;
    final maxIdx = values.indexOf(max);
    return timestamps[maxIdx];
  }

  DateTime? get firstTime => timestamps.isNotEmpty ? timestamps.first : null;
  DateTime? get lastTime => timestamps.isNotEmpty ? timestamps.last : null;

  // میانه
  double get median {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  // انحراف معیار
  double get stdDev {
    if (count < 2) return 0;
    final mean = avg;
    final sumSquares =
        values.fold(0.0, (sum, v) => sum + math.pow(v - mean, 2));
    return math.sqrt(sumSquares / (count - 1));
  }

  // واریانس
  double get variance => (math.pow(stdDev, 2) as double);

  // درصد تغییر
  double get changePercent {
    if (values.length < 2 || values.first == 0) return 0;
    return ((values.last - values.first) / values.first) * 100;
  }
}

class ReportStatsView extends StatefulWidget {
  final List<Map<String, dynamic>> seriesData;

  const ReportStatsView({super.key, required this.seriesData});

  @override
  State<ReportStatsView> createState() => _ReportStatsViewState();
}

class _ReportStatsViewState extends State<ReportStatsView> {
  final GlobalKey _statsKey = GlobalKey();
  List<SeriesStats> _stats = [];
  bool _isExporting = false;
  pw.Font? _pdfRegular;
  pw.Font? _pdfBold;

  @override
  void initState() {
    super.initState();
    _buildStats();
  }

  @override
  void didUpdateWidget(ReportStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesData != widget.seriesData) {
      _buildStats();
    }
  }

  void _buildStats() {
    _stats = [];
    for (final s in widget.seriesData) {
      final points = s['dataPoints'] as List? ?? [];
      if (points.isEmpty) continue;

      final values = <double>[];
      final timestamps = <DateTime>[];

      for (final p in points) {
        values.add((p['value'] as num).toDouble());
        timestamps.add(DateTime.parse(p['timestamp'] as String));
      }

      _stats.add(SeriesStats(
        tag: s['widgetLabel'] ?? '?',
        unit: s['unit'] ?? '',
        values: values,
        timestamps: timestamps,
      ));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_stats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, color: Colors.white24, size: 64),
            SizedBox(height: 12),
            Text('داده‌ای برای نمایش آمار وجود ندارد',
                style:
                    TextStyle(color: Colors.white38, fontFamily: 'Vazirmatn')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // نوار ابزار
        _buildToolbar(),

        // کارت‌های آمار
        Expanded(
          child: Stack(
            children: [
              RepaintBoundary(
                key: _statsKey,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stats.length,
                  itemBuilder: (context, index) =>
                      _buildStatsCard(_stats[index]),
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
                        Text(
                          'در حال آماده‌سازی PDF...',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // لودینگ Export
        if (_isExporting)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black54,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(width: 16),
                Text('در حال ایجاد PDF...',
                    style: TextStyle(
                        color: Colors.white, fontFamily: 'Vazirmatn')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          const Text(
            'آمار تگ‌ها',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${PersianUtils.toPersian(_stats.length)} تگ',
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                color: Colors.blue,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          _actionButton(
            Icons.print,
            'چاپ آمار',
            _printStats,
          ),
          const SizedBox(width: 6),
          _actionButton(
            Icons.picture_as_pdf,
            'خروجی PDF',
            _exportStatsPdf,
            showSpinner: _isExporting,
          ),
        ],
      ),
    );
  }

  Future<void> _printStats() async {
    if (_stats.isEmpty) {
      _showStatsMsg(';آماری برای چاپ وجود ندارد', error: true);
      return;
    }

    try {
      final bytes = await _buildStatsPdfBytes();
      if (bytes == null) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showStatsMsg(';خطا در چاپ: $e', error: true);
    }
  }

  Future<void> _exportStatsPdf() async {
    if (_stats.isEmpty) {
      _showStatsMsg(';آماری برای خروجی وجود ندارد', error: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final bytes = await _buildStatsPdfBytes();
      if (bytes == null) return;

      final filename =
          'stats_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await saveFileToDownloads(bytes, filename);

      if (path != null) {
        _showStatsMsg(';PDF آمار ذخیره شد:\n$path');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        _showStatsMsg(';PDF آمار آماده ارسال شد');
      }
    } catch (e) {
      _showStatsMsg(';خطا در ایجاد PDF: $e', error: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showStatsMsg(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12,
          ),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

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
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  Widget _buildStatsCard(SeriesStats stats) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.label, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.tag,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'واحد: ${stats.unit.isEmpty ? '-' : stats.unit}',
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontFamily: 'Vazirmatn'),
                      ),
                    ],
                  ),
                ),
                // درصد تغییر
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: stats.changePercent >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats.changePercent >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: stats.changePercent >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.changePercent >= 0 ? '+' : ''}${PersianUtils.formatNumber(stats.changePercent)}٪',
                        style: TextStyle(
                          color: stats.changePercent >= 0
                              ? Colors.green
                              : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 16),

            // Sparkline
            SizedBox(
              height: 60,
              child: _buildSparkline(stats),
            ),

            const SizedBox(height: 16),

            // آمارهای اصلی
            Row(
              children: [
                _buildStatBox(
                    'تعداد', PersianUtils.formatInt(stats.count), Colors.blue),
                _buildStatBox(
                    'میانگین',
                    '${PersianUtils.formatNumber(stats.avg)} ${stats.unit}',
                    Colors.green),
                _buildStatBox(
                    'میانه',
                    '${PersianUtils.formatNumber(stats.median)} ${stats.unit}',
                    Colors.purple),
                _buildStatBox(
                    'مجموع',
                    '${PersianUtils.formatNumber(stats.sum)} ${stats.unit}',
                    Colors.orange),
              ],
            ),

            const SizedBox(height: 12),

            // Min/Max با زمان
            Row(
              children: [
                Expanded(
                  child: _buildMinMaxBox(
                    'حداقل',
                    stats.min,
                    stats.unit,
                    stats.minTime,
                    Colors.cyan,
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMinMaxBox(
                    'حداکثر',
                    stats.max,
                    stats.unit,
                    stats.maxTime,
                    Colors.orange,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // آمارهای پیشرفته
            Row(
              children: [
                _buildStatBox('انحراف معیار',
                    PersianUtils.formatNumber(stats.stdDev), Colors.pink),
                _buildStatBox('واریانس',
                    PersianUtils.formatNumber(stats.variance), Colors.indigo),
                _buildStatBox('بازه', PersianUtils.formatNumber(stats.range),
                    Colors.teal),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 12),

            // بازه زمانی
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  'از ${stats.firstTime != null ? PersianUtils.formatFull(stats.firstTime!) : '-'}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontFamily: 'Vazirmatn'),
                ),
                const Text(' تا ',
                    style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'Vazirmatn')),
                Text(
                  stats.lastTime != null
                      ? PersianUtils.formatFull(stats.lastTime!)
                      : '-',
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkline(SeriesStats stats) {
    if (stats.values.isEmpty) return const SizedBox();

    // Downsample for performance
    final step = math.max(1, stats.values.length ~/ 100);
    final spots = <FlSpot>[];
    for (var i = 0; i < stats.values.length; i += step) {
      spots.add(FlSpot(i.toDouble(), stats.values[i]));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7), fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinMaxBox(String label, double value, String unit,
      DateTime? time, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.7), fontSize: 10)),
                Text(
                  '${PersianUtils.formatNumber(value)} $unit',
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (time != null)
                  Text(
                    PersianUtils.formatDateTime(time),
                    style: TextStyle(
                        color: color.withValues(alpha: 0.5), fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStatsPdfFonts() async {
    if (_pdfRegular != null) return;

    try {
      _pdfRegular = pw.Font.ttf(
        await rootBundle.load('assests/fonts/Vazirmatn-Regular.ttf'),
      );
      _pdfBold = pw.Font.ttf(
        await rootBundle.load('assests/fonts/Vazirmatn-Bold.ttf'),
      );
      debugPrint('✅ فونت PDF آمار از assets لود شد');
      return;
    } catch (e) {
      debugPrint('⚠️ فونت محلی آمار لود نشد: $e');
    }

    try {
      _pdfRegular = await PdfGoogleFonts.vazirmatnRegular();
      _pdfBold = await PdfGoogleFonts.vazirmatnBold();
      debugPrint('✅ فونت PDF آمار از Google Fonts لود شد');
    } catch (e) {
      debugPrint('❌ هیچ فونت فارسی برای آمار لود نشد: $e');
    }
  }

  Future<Uint8List?> _buildStatsPdfBytes() async {
    if (_stats.isEmpty) return null;

    await _loadStatsPdfFonts();

    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        textDirection: pw.TextDirection.rtl,
        theme: _pdfRegular != null
            ? pw.ThemeData.withFont(
                base: _pdfRegular!,
                bold: _pdfBold ?? _pdfRegular!,
              )
            : null,
        build: (pw.Context context) {
          return [
            _statsPdfHeader(now),
            pw.SizedBox(height: 12),
            _statsSummaryStrip(),
            pw.SizedBox(height: 14),
            _statsPdfTable(),
            pw.SizedBox(height: 16),
            _statsPdfFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _statsPdfHeader(DateTime now) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1E293B'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تاریخ تولید: ${PersianUtils.formatDateTime(now)}',
            style: pw.TextStyle(
              font: _pdfRegular,
              fontSize: 9,
              color: PdfColors.grey400,
            ),
          ),
          pw.Text(
            'گزارش آماری',
            style: pw.TextStyle(
              font: _pdfBold,
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _statsSummaryStrip() {
    final totalPoints = _stats.fold<int>(0, (sum, s) => sum + s.count);
    final totalTags = _stats.length;

    double globalMin = 0;
    double globalMax = 0;
    double globalAvg = 0;

    if (_stats.isNotEmpty) {
      globalMin = _stats.map((s) => s.min).reduce(math.min);
      globalMax = _stats.map((s) => s.max).reduce(math.max);
      globalAvg =
          _stats.map((s) => s.avg).reduce((a, b) => a + b) / _stats.length;
    }

    return pw.Row(
      children: [
        _statsMiniBox(
          'تعداد تگ‌ها',
          PersianUtils.toPersian(totalTags),
          PdfColors.blue600,
          PdfColors.blue50,
        ),
        pw.SizedBox(width: 8),
        _statsMiniBox(
          'کل نقاط',
          PersianUtils.toPersian(totalPoints),
          PdfColors.green600,
          PdfColors.green50,
        ),
        pw.SizedBox(width: 8),
        _statsMiniBox(
          'حداقل کل',
          PersianUtils.formatNumber(globalMin),
          PdfColors.cyan600,
          PdfColors.cyan50,
        ),
        pw.SizedBox(width: 8),
        _statsMiniBox(
          'حداکثر کل',
          PersianUtils.formatNumber(globalMax),
          PdfColors.orange600,
          PdfColors.orange50,
        ),
        pw.SizedBox(width: 8),
        _statsMiniBox(
          'میانگین کل',
          PersianUtils.formatNumber(globalAvg),
          PdfColors.purple600,
          PdfColors.purple50,
        ),
      ],
    );
  }

  pw.Widget _statsMiniBox(
    String label,
    String value,
    PdfColor color,
    PdfColor bg,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color, width: 0.6),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: _pdfRegular,
                fontSize: 8,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: _pdfBold ?? _pdfRegular,
                fontSize: 13,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _statsPdfTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5), // تگ
        1: pw.FixedColumnWidth(45), // واحد
        2: pw.FixedColumnWidth(55), // تعداد
        3: pw.FixedColumnWidth(65), // میانگین
        4: pw.FixedColumnWidth(65), // میانه
        5: pw.FixedColumnWidth(65), // حداقل
        6: pw.FixedColumnWidth(65), // حداکثر
        7: pw.FixedColumnWidth(70), // انحراف معیار
        8: pw.FixedColumnWidth(70), // تغییر
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#334155')),
          children: [
            'تگ',
            'واحد',
            'تعداد',
            'میانگین',
            'میانه',
            'حداقل',
            'حداکثر',
            'انحراف معیار',
            '٪ تغییر',
          ]
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      font: _pdfBold,
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ..._stats.asMap().entries.map((entry) {
          final index = entry.key;
          final s = entry.value;
          final bg = index.isEven ? PdfColors.grey50 : PdfColors.white;
          final changeColor =
              s.changePercent >= 0 ? PdfColors.green700 : PdfColors.red700;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _statsCell(s.tag, bold: true),
              _statsCell(s.unit),
              _statsCell(PersianUtils.toPersian(s.count)),
              _statsCell(PersianUtils.formatNumber(s.avg)),
              _statsCell(PersianUtils.formatNumber(s.median)),
              _statsCell(PersianUtils.formatNumber(s.min)),
              _statsCell(PersianUtils.formatNumber(s.max)),
              _statsCell(PersianUtils.formatNumber(s.stdDev)),
              _statsCell(
                '${s.changePercent >= 0 ? '+' : ''}${PersianUtils.formatNumber(s.changePercent)}٪',
                color: changeColor,
                bold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _statsCell(
    String text, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? (_pdfBold ?? _pdfRegular) : _pdfRegular,
          fontSize: 8.5,
          color: color ?? PdfColors.grey800,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  pw.Widget _statsPdfFooter() {
    final totalPoints = _stats.fold<int>(0, (sum, s) => sum + s.count);

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
                font: _pdfRegular,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
            pw.Text(
              'مجموع: ${PersianUtils.toPersian(_stats.length)} تگ | ${PersianUtils.toPersian(totalPoints)} نقطه',
              style: pw.TextStyle(
                font: _pdfRegular,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }



}
