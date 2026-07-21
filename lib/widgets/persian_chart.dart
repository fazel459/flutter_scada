// ═══════════════════════════════════════════════════════════
//  PersianChart — چارت SCADA با زوم، تاریخ شمسی و خروجی PDF
//  نسخه کامل — بدون path_provider / dart:io / share_plus
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_scada/utils/persian_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/file_saver_stub.dart'
    if (dart.library.io) '../utils/file_saver_io.dart';

// ─────────────── مدل‌های داده ───────────────

class ChartDataPoint {
  final DateTime timestamp;
  final double value;

  ChartDataPoint({required this.timestamp, required this.value});
}

class ChartSeriesData {
  final String id;
  final String label;
  final String unit;
  final List<ChartDataPoint> points;
  final Color color;
  bool isVisible;

  ChartSeriesData({
    required this.id,
    required this.label,
    required this.unit,
    required this.points,
    required this.color,
    this.isVisible = true,
  });

  double get minValue =>
      points.isEmpty ? 0 : points.map((p) => p.value).reduce(math.min);
  double get maxValue =>
      points.isEmpty ? 0 : points.map((p) => p.value).reduce(math.max);
  double get avgValue => points.isEmpty
      ? 0
      : points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
}

// ─────────────── ویجت اصلی ───────────────

class PersianChart extends StatefulWidget {
  final List<ChartSeriesData> seriesList;
  final DateTime fromDate;
  final DateTime toDate;
  final String title;

  const PersianChart({
    super.key,
    required this.seriesList,
    required this.fromDate,
    required this.toDate,
    this.title = 'نمودار گزارش',
  });

  @override
  State<PersianChart> createState() => _PersianChartState();
}

class _PersianChartState extends State<PersianChart> {
  final GlobalKey _chartKey = GlobalKey();

  // ── محدوده‌های نمایش (قابل زوم) ──
  double _minX = 0, _maxX = 1;
  double _minY = 0, _maxY = 1;
  double _fullMinX = 0, _fullMaxX = 1;
  double _fullMinY = 0, _fullMaxY = 1;

  // ── padding چارت برای محاسبه زوم ──
  static const double _padLeft = 55;
  static const double _padRight = 20;
  static const double _padTop = 16;
  static const double _padBottom = 40;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _calculateBounds();
  }

  @override
  void didUpdateWidget(PersianChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList) {
      _calculateBounds();
    }
  }

  void _calculateBounds() {
    _minX = widget.fromDate.millisecondsSinceEpoch.toDouble();
    _maxX = widget.toDate.millisecondsSinceEpoch.toDouble();

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (final series in widget.seriesList) {
      if (!series.isVisible) continue;
      for (final point in series.points) {
        if (point.value < minVal) minVal = point.value;
        if (point.value > maxVal) maxVal = point.value;
      }
    }

    if (minVal == double.infinity) {
      minVal = 0;
      maxVal = 100;
    }

    final padding = (maxVal - minVal) * 0.1;
    _minY = minVal - padding;
    _maxY = maxVal + padding;

    _fullMinX = _minX;
    _fullMaxX = _maxX;
    _fullMinY = _minY;
    _fullMaxY = _maxY;
  }

  // ═══════════════ زوم و پن ═══════════════

  void _zoom(double factor, {double anchorFractionX = 0.5}) {
    setState(() {
      final fullRangeX = _fullMaxX - _fullMinX;
      final rangeX = _maxX - _minX;
      final newRangeX =
          (rangeX * factor).clamp(fullRangeX / 100, fullRangeX * 1.05);

      final anchorX = _minX + rangeX * anchorFractionX;
      _minX = anchorX - newRangeX * anchorFractionX;
      _maxX = _minX + newRangeX;

      final fullRangeY = _fullMaxY - _fullMinY;
      final rangeY = _maxY - _minY;
      final newRangeY =
          (rangeY * factor).clamp(fullRangeY / 100, fullRangeY * 1.05);

      final anchorY = (_minY + _maxY) / 2;
      _minY = anchorY - newRangeY / 2;
      _maxY = anchorY + newRangeY / 2;
    });
  }

  void _resetZoom() {
    setState(() {
      _minX = _fullMinX;
      _maxX = _fullMaxX;
      _minY = _fullMinY;
      _maxY = _fullMaxY;
    });
  }

  void _pan(Offset delta, Size chartSize) {
    setState(() {
      final chartW = chartSize.width - _padLeft - _padRight;
      final chartH = chartSize.height - _padTop - _padBottom;
      if (chartW <= 0 || chartH <= 0) return;

      final rangeX = _maxX - _minX;
      final rangeY = _maxY - _minY;

      var dxData = -delta.dx * rangeX / chartW;
      var dyData = delta.dy * rangeY / chartH;

      // Clamp — از محدوده داده خارج نشود
      if (_minX + dxData < _fullMinX - rangeX * 0.1) {
        dxData = _fullMinX - rangeX * 0.1 - _minX;
      }
      if (_maxX + dxData > _fullMaxX + rangeX * 0.1) {
        dxData = _fullMaxX + rangeX * 0.1 - _maxX;
      }
      if (_minY + dyData < _fullMinY - rangeY * 0.2) {
        dyData = _fullMinY - rangeY * 0.2 - _minY;
      }
      if (_maxY + dyData > _fullMaxY + rangeY * 0.2) {
        dyData = _fullMaxY + rangeY * 0.2 - _maxY;
      }

      _minX += dxData;
      _maxX += dxData;
      _minY += dyData;
      _maxY += dyData;
    });
  }

  int get _zoomPercent {
    if (_fullMaxX == _fullMinX || _maxX == _minX) return 100;
    final full = _fullMaxX - _fullMinX;
    final current = _maxX - _minX;
    return (full / current * 100).round();
  }

  void _toggleSeriesVisibility(int index) {
    setState(() {
      widget.seriesList[index].isVisible = !widget.seriesList[index].isVisible;
      _calculateBounds();
    });
  }

  // ═══════════════ UI ═══════════════

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildLegend(),
        Expanded(
          child: Stack(
            children: [
              RepaintBoundary(
                key: _chartKey,
                child: _buildChart(),
              ),
              if (_isExporting)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('در حال آماده‌سازی...',
                            style: TextStyle(
                                fontFamily: 'Vazirmatn', color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildStatsBar(),
      ],
    );
  }

  // ─── Toolbar با دکمه‌های زوم و خروجی ───

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),

          // ── گروه زوم ──
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarButton(
                  icon: Icons.add,
                  tooltip: 'بزرگ‌نمایی',
                  onTap: () => _zoom(1 / 1.4),
                ),
                _toolbarButton(
                  icon: Icons.remove,
                  tooltip: 'کوچک‌نمایی',
                  onTap: () => _zoom(1.4),
                ),
                _toolbarButton(
                  icon: Icons.zoom_out_map,
                  tooltip: 'نمایش کامل',
                  onTap: _resetZoom,
                ),
              ],
            ),
          ),

          // درصد زوم
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _zoomPercent > 100
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${PersianUtils.toPersian(_zoomPercent)}٪',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    _zoomPercent > 100 ? Colors.blue : const Color(0xFF64748B),
              ),
            ),
          ),

          const Spacer(),

          // ── دکمه‌های خروجی — مستقیم به توابع جدید ──
          _toolbarButton(
            icon: Icons.image,
            tooltip: 'ذخیره تصویر',
            onTap: _exportAsImage,
          ),
          const SizedBox(width: 6),
          _toolbarButton(
            icon: Icons.picture_as_pdf,
            tooltip: 'خروجی PDF',
            onTap: _exportAsPdf,
          ),
          const SizedBox(width: 6),
          _toolbarButton(
            icon: Icons.print,
            tooltip: 'چاپ',
            onTap: _printChart,
          ),
          const SizedBox(width: 6),
          _toolbarButton(
            icon: Icons.share,
            tooltip: 'اشتراک‌گذاری',
            onTap: _shareChart,
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  // ─── Legend تعاملی ───

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(widget.seriesList.length, (index) {
          final series = widget.seriesList[index];
          return GestureDetector(
            onTap: () => _toggleSeriesVisibility(index),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: series.isVisible ? series.color : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: series.isVisible
                      ? null
                      : const Icon(Icons.visibility_off,
                          size: 12, color: Colors.white54),
                ),
                const SizedBox(width: 6),
                Text(
                  '${series.label} (${series.unit})',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: series.isVisible ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                    decoration:
                        series.isVisible ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── چارت با زوم موس ───

  Widget _buildChart() {
    final visibleSeries = widget.seriesList.where((s) => s.isVisible).toList();

    if (visibleSeries.isEmpty) {
      return const Center(
        child: Text('هیچ سری داده‌ای انتخاب نشده',
            style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white38)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          // ── زوم با اسکرول موس ──
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final factor = event.scrollDelta.dy > 0 ? 1.2 : 1 / 1.2;
              final fraction = ((event.localPosition.dx - _padLeft) /
                      (chartSize.width - _padLeft - _padRight))
                  .clamp(0.0, 1.0);
              _zoom(factor, anchorFractionX: fraction);
            }
          },
          child: GestureDetector(
            onPanUpdate: (details) => _pan(details.delta, chartSize),
            onDoubleTap: _resetZoom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: LineChart(
                _buildLineChartData(visibleSeries),
                duration: const Duration(milliseconds: 150),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── داده کامل چارت ───

  LineChartData _buildLineChartData(List<ChartSeriesData> visibleSeries) {
    final rangeX = _maxX - _minX;
    final rangeY = _maxY - _minY;
    final double intervalX = rangeX > 0 ? rangeX / 6.0 : 1.0;
    final double intervalY = rangeY > 0 ? rangeY / 5.0 : 1.0;
    final isLongRange = widget.toDate.difference(widget.fromDate).inDays > 2;

    return LineChartData(
      minX: _minX,
      maxX: _maxX,
      minY: _minY,
      maxY: _maxY,
      clipData: const FlClipData.all(),
      backgroundColor: const Color(0xFF0A0F1A),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: intervalY,
        verticalInterval: intervalX,
        getDrawingHorizontalLine: (v) => const FlLine(
          color: Color(0xFF1E293B),
          strokeWidth: 1,
          dashArray: [4, 6],
        ),
        getDrawingVerticalLine: (v) => const FlLine(
          color: Color(0xFF17223B),
          strokeWidth: 1,
          dashArray: [4, 6],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(color: Color(0xFF475569)),
          bottom: BorderSide(color: Color(0xFF475569)),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: intervalX,
            getTitlesWidget: (value, meta) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isLongRange
                      ? PersianUtils.formatDate(date)
                      : PersianUtils.formatTime(date),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: intervalY,
            getTitlesWidget: (value, meta) => Text(
              PersianUtils.formatNumber(value, decimals: 1),
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                color: Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(10),
          tooltipBorder: const BorderSide(color: Color(0xFF475569)),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              if (spot.barIndex >= visibleSeries.length) return null;
              final series = visibleSeries[spot.barIndex];
              final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              return LineTooltipItem(
                '',
                const TextStyle(),
                children: [
                  TextSpan(
                    text: '${series.label}\n',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: series.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text:
                        '${PersianUtils.formatNumber(spot.y)} ${series.unit}\n',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: PersianUtils.formatDateTime(date),
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              const FlLine(
                  color: Colors.white24, strokeWidth: 1, dashArray: [4, 4]),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 5,
                  color: bar.color ?? Colors.blue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
            );
          }).toList();
        },
      ),
      lineBarsData: visibleSeries.map((series) {
        final points = _downsamplePoints(series.points, maxPoints: 600);
        return LineChartBarData(
          spots: points
              .map((p) => FlSpot(
                    p.timestamp.millisecondsSinceEpoch.toDouble(),
                    p.value,
                  ))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.2,
          color: series.color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: points.length <= 40,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3,
              color: series.color,
              strokeWidth: 1,
              strokeColor: Colors.white54,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                series.color.withValues(alpha: 0.25),
                series.color.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      }).toList(),
      extraLinesData: ExtraLinesData(
        horizontalLines: _buildMinMaxLines(visibleSeries),
      ),
    );
  }

  List<ChartDataPoint> _downsamplePoints(List<ChartDataPoint> points,
      {int maxPoints = 600}) {
    if (points.length <= maxPoints) return points;

    final step = points.length / maxPoints;
    final result = <ChartDataPoint>[];

    for (var i = 0.0; i < points.length; i += step) {
      result.add(points[i.floor()]);
    }
    if (result.isNotEmpty && result.last != points.last) {
      result.add(points.last);
    }
    return result;
  }

  List<HorizontalLine> _buildMinMaxLines(List<ChartSeriesData> visibleSeries) {
    final lines = <HorizontalLine>[];

    for (final series in visibleSeries) {
      if (series.points.isEmpty) continue;

      lines.add(HorizontalLine(
        y: series.minValue,
        color: series.color.withValues(alpha: 0.4),
        strokeWidth: 1,
        dashArray: [8, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: TextStyle(
              fontFamily: 'Vazirmatn', color: series.color, fontSize: 9),
          labelResolver: (line) =>
              'حداقل: ${PersianUtils.formatNumber(line.y)}',
        ),
      ));

      lines.add(HorizontalLine(
        y: series.maxValue,
        color: series.color.withValues(alpha: 0.4),
        strokeWidth: 1,
        dashArray: [8, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: TextStyle(
              fontFamily: 'Vazirmatn', color: series.color, fontSize: 9),
          labelResolver: (line) =>
              'حداکثر: ${PersianUtils.formatNumber(line.y)}',
        ),
      ));
    }
    return lines;
  }

  // ─── نوار آمار پایین ───

  Widget _buildStatsBar() {
    final visibleSeries = widget.seriesList.where((s) => s.isVisible).toList();
    if (visibleSeries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: visibleSeries.map((series) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: series.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('${series.label}: ',
                  style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Colors.white54,
                      fontSize: 10)),
              Text('حداقل: ${PersianUtils.formatNumber(series.minValue)} | ',
                  style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Colors.cyan,
                      fontSize: 10)),
              Text('حداکثر: ${PersianUtils.formatNumber(series.maxValue)} | ',
                  style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Colors.orange,
                      fontSize: 10)),
              Text('میانگین: ${PersianUtils.formatNumber(series.avgValue)}',
                  style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: Colors.green,
                      fontSize: 10)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EXPORT — نسخه نهایی (فقط bytes — بدون File و path_provider)
  // ═══════════════════════════════════════════════════════════

  Future<Uint8List?> _captureChart() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  /// ساخت PDF کامل در حافظه — هیچ فایلی ساخته نمی‌شود
  Future<Uint8List?> _buildPdfBytes() async {
    final imageBytes = await _captureChart();
    if (imageBytes == null) return null;

    // فونت فارسی (اختیاری — اگر نبود ادامه می‌دهد)
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = pw.Font.ttf(
          await rootBundle.load('assests/fonts/Vazirmatn-Regular.ttf'));
      bold = pw.Font.ttf(
          await rootBundle.load('assests/fonts/Vazirmatn-Bold.ttf'));
    } catch (_) {
      debugPrint(' هیچ فونت فارسی‌ای لود نشد: ادامه بدون فونت فارسی');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(' هیچ فونت فارسی‌ای لود نشد: ادامه بدون فونت فارسی',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: Colors.red,
        ),
      );
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        theme: regular != null
            ? pw.ThemeData.withFont(base: regular, bold: bold)
            : null,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // هدر
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E293B'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      widget.title,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'از ${PersianUtils.formatFull(widget.fromDate)}  تا  '
                      '${PersianUtils.formatFull(widget.toDate)}   |   '
                      '${PersianUtils.toPersian(widget.seriesList.length)} تگ',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 11,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // تصویر چارت
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 14),

              // جدول آمار
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#334155')),
                    children: ['تگ', 'واحد', 'حداقل', 'حداکثر', 'میانگین']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                h,
                                style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 10,
                                  color: PdfColors.white,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                  ...widget.seriesList
                      .where((s) => s.isVisible)
                      .map((s) => pw.TableRow(
                            children: [
                              s.label,
                              s.unit,
                              PersianUtils.formatNumber(s.minValue),
                              PersianUtils.formatNumber(s.maxValue),
                              PersianUtils.formatNumber(s.avgValue),
                            ]
                                .map((c) => pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                        c,
                                        style: pw.TextStyle(
                                            font: regular, fontSize: 9),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ))
                                .toList(),
                          )),
                ],
              ),
              pw.SizedBox(height: 10),

              // فوتر
              pw.Text(
                'تاریخ تولید: ${PersianUtils.formatDateTime(DateTime.now())}   |   سیستم SCADA',
                style: pw.TextStyle(
                    font: regular, fontSize: 9, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// ذخیره تصویر (داخل PDF — بدون نیاز به فایل)
  Future<void> _exportAsImage() async {
    setState(() => _isExporting = true);
    final imageBytes = await _captureChart();
    if (imageBytes == null) {
      _showError('خطا در ایجاد تصویر');
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => pw.Center(
            child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
      final bytes = await pdf.save();
      final filename =
          'scada_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final savedPath = await saveFileToDownloads(bytes, filename);

      if (savedPath != null) {
        _showSuccess('PDF ذخیره شد:\n$savedPath');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      _showError('خطا در ایجاد PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// خروجی PDF کامل (چارت + جدول آمار)
  Future<void> _exportAsPdf() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null) {
        _showError('خطا در ایجاد PDF');
        return;
      }
      final filename =
          'scada_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final savedPath = await saveFileToDownloads(bytes, filename);

      if (savedPath != null) {
        _showSuccess('PDF ذخیره شد:\n$savedPath');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      _showError(';خطا در ایجاد PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// چاپ مستقیم
  Future<void> _printChart() async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => await _buildPdfBytes() ?? Uint8List(0),
      );
    } catch (e) {
      _showError('خطا در چاپ: $e');
    }
  }

  /// اشتراک‌گذاری
  Future<void> _shareChart() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildPdfBytes();
      if (bytes == null) {
        _showError('خطا در ایجاد فایل');
        return;
      }

      final filename =
          'scada_chart_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedPath = await saveFileToDownloads(bytes, filename);
      if (savedPath != null) {
        _showSuccess('فایل ذخیره شد:\n$savedPath');
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      _showError('خطا در اشتراک‌گذاری: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

// ── SnackBar موفقیت ──
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'باشه',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: Colors.red,
      ),
    );
  }
}
