import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../utils/persian_utils.dart';

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
    final sumSquares = values.fold(0.0, (sum, v) => sum + math.pow(v - mean, 2));
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
            Text('داده‌ای برای نمایش آمار وجود ندارد', style: TextStyle(color: Colors.white38,fontFamily: 'Vazirmatn')),
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
          child: RepaintBoundary(
            key: _statsKey,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stats.length,
              itemBuilder: (context, index) => _buildStatsCard(_stats[index]),
            ),
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
                Text('در حال ایجاد PDF...', style: TextStyle(color: Colors.white,fontFamily: 'Vazirmatn')),
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,fontFamily: 'Vazirmatn'),
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
              style: const TextStyle(color: Colors.blue, fontSize: 11,fontFamily: 'Vazirmatn'),
            ),
          ),
          const Spacer(),
          
          // Export PDF
          ElevatedButton.icon(
            onPressed: _exportAsPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('خروجی PDF', style: TextStyle(fontSize: 11,fontFamily: 'Vazirmatn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
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
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'واحد: ${stats.unit.isEmpty ? '-' : stats.unit}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11,fontFamily: 'Vazirmatn'),
                      ),
                    ],
                  ),
                ),
                // درصد تغییر
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: stats.changePercent >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats.changePercent >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: stats.changePercent >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.changePercent >= 0 ? '+' : ''}${PersianUtils.formatNumber(stats.changePercent)}٪',
                        style: TextStyle(
                          color: stats.changePercent >= 0 ? Colors.green : Colors.red,
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
                _buildStatBox('تعداد', PersianUtils.formatInt(stats.count), Colors.blue),
                _buildStatBox('میانگین', '${PersianUtils.formatNumber(stats.avg)} ${stats.unit}', Colors.green),
                _buildStatBox('میانه', '${PersianUtils.formatNumber(stats.median)} ${stats.unit}', Colors.purple),
                _buildStatBox('مجموع', '${PersianUtils.formatNumber(stats.sum)} ${stats.unit}', Colors.orange),
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
                _buildStatBox('انحراف معیار', PersianUtils.formatNumber(stats.stdDev), Colors.pink),
                _buildStatBox('واریانس', PersianUtils.formatNumber(stats.variance), Colors.indigo),
                _buildStatBox('بازه', PersianUtils.formatNumber(stats.range), Colors.teal),
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
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11,fontFamily: 'Vazirmatn'),
                ),
                const Text(' تا ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11,fontFamily: 'Vazirmatn')),
                Text(
                  stats.lastTime != null ? PersianUtils.formatFull(stats.lastTime!) : '-',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                colors: [Colors.blue.withValues(alpha: 0.3), Colors.blue.withValues(alpha: 0.0)],
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
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinMaxBox(String label, double value, String unit, DateTime? time, Color color, IconData icon) {
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
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
                Text(
                  '${PersianUtils.formatNumber(value)} $unit',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (time != null)
                  Text(
                    PersianUtils.formatDateTime(time),
                    style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    setState(() => _isExporting = true);
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            // عنوان
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E293B'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'گزارش آماری',
                style: const pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // جدول آمار
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600),
              children: [
                // هدر
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF334155)),
                  children: [
                    _pdfHeader('درصد تغییر'),
                    _pdfHeader('انحراف معیار'),
                    _pdfHeader('حداکثر'),
                    _pdfHeader('حداقل'),
                    _pdfHeader('میانگین'),
                    _pdfHeader('تعداد'),
                    _pdfHeader('تگ'),
                  ],
                ),
                // داده‌ها
                ..._stats.map((s) => pw.TableRow(
                  children: [
                    _pdfCell('${PersianUtils.formatNumber(s.changePercent)}٪'),
                    _pdfCell(PersianUtils.formatNumber(s.stdDev)),
                    _pdfCell('${PersianUtils.formatNumber(s.max)} ${s.unit}'),
                    _pdfCell('${PersianUtils.formatNumber(s.min)} ${s.unit}'),
                    _pdfCell('${PersianUtils.formatNumber(s.avg)} ${s.unit}'),
                    _pdfCell(PersianUtils.formatInt(s.count)),
                    _pdfCell(s.tag),
                  ],
                )),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Text(
              'تاریخ تولید: ${PersianUtils.formatDateTime(DateTime.now())}',
              style: const pw.TextStyle( fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/stats_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'گزارش آماری SCADA');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e',style: const TextStyle(fontFamily: 'Vazirmatn'),), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
    );
  }
}
