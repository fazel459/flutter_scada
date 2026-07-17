import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/persian_utils.dart';

/// مدل داده برای هر سری
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

  double get minValue => points.isEmpty ? 0 : points.map((p) => p.value).reduce(math.min);
  double get maxValue => points.isEmpty ? 0 : points.map((p) => p.value).reduce(math.max);
  double get avgValue => points.isEmpty ? 0 : points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
}

class ChartDataPoint {
  final DateTime timestamp;
  final double value;

  ChartDataPoint({required this.timestamp, required this.value});
}

/// ویجت اصلی چارت فارسی
class PersianChart extends StatefulWidget {
  final List<ChartSeriesData> seriesList;
  final DateTime fromDate;
  final DateTime toDate;
  final String title;
  final Function(ChartDataPoint, ChartSeriesData)? onPointTap;

  const PersianChart({
    super.key,
    required this.seriesList,
    required this.fromDate,
    required this.toDate,
    this.title = 'نمودار گزارش',
    this.onPointTap,
  });

  @override
  State<PersianChart> createState() => _PersianChartState();
}

class _PersianChartState extends State<PersianChart> with SingleTickerProviderStateMixin {
  final GlobalKey _chartKey = GlobalKey();
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Zoom & Pan
  double _minX = 0;
  double _maxX = 1;
  double _minY = 0;
  double _maxY = 1;
  
  // Touch tracking
  Offset? _crosshairPosition;
  
  // Export state
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
    _calculateBounds();
  }

  @override
  void didUpdateWidget(PersianChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList) {
      _calculateBounds();
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _calculateBounds() {
    if (widget.seriesList.isEmpty) return;
    
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
    
    // Add 10% padding
    final padding = (maxVal - minVal) * 0.1;
    _minY = minVal - padding;
    _maxY = maxVal + padding;
  }

  void _resetZoom() {
    setState(() {
      _calculateBounds();
    });
  }

  void _toggleSeriesVisibility(int index) {
    setState(() {
      widget.seriesList[index].isVisible = !widget.seriesList[index].isVisible;
      _calculateBounds();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        _buildToolbar(),
        
        // Legend
        _buildLegend(),
        
        // Chart
        Expanded(
          child: Stack(
            children: [
              RepaintBoundary(
                key: _chartKey,
                child: _buildChart(),
              ),
              
              // Crosshair overlay
              if (_crosshairPosition != null)
                _buildCrosshair(),
              
              // Loading overlay for export
              if (_isExporting)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('در حال ایجاد PDF...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Stats bar
        _buildStatsBar(),
      ],
    );
  }

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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Spacer(),
          
          // Reset zoom
          _toolbarButton(
            icon: Icons.zoom_out_map,
            tooltip: 'بازنشانی زوم',
            onTap: _resetZoom,
          ),
          
          const SizedBox(width: 8),
          
          // Export PNG
          _toolbarButton(
            icon: Icons.image,
            tooltip: 'ذخیره تصویر',
            onTap: _exportAsImage,
          ),
          
          const SizedBox(width: 8),
          
          // Export PDF
          _toolbarButton(
            icon: Icons.picture_as_pdf,
            tooltip: 'خروجی PDF',
            onTap: _exportAsPdf,
          ),
          
          const SizedBox(width: 8),
          
          // Print
          _toolbarButton(
            icon: Icons.print,
            tooltip: 'چاپ',
            onTap: _printChart,
          ),
          
          const SizedBox(width: 8),
          
          // Share
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
                      : const Icon(Icons.visibility_off, size: 12, color: Colors.white54),
                ),
                const SizedBox(width: 6),
                Text(
                  '${series.label} (${series.unit})',
                  style: TextStyle(
                    color: series.isVisible ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                    decoration: series.isVisible ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChart() {
    final visibleSeries = widget.seriesList.where((s) => s.isVisible).toList();
    
    if (visibleSeries.isEmpty) {
      return const Center(
        child: Text('هیچ سری داده‌ای انتخاب نشده', style: TextStyle(color: Colors.white38)),
      );
    }

    return GestureDetector(
      onScaleUpdate: (details) {
        // Zoom handling
        if (details.scale != 1.0) {
          setState(() {
            final factor = 1 / details.scale;
            final rangeX = (_maxX - _minX) * factor;
            final rangeY = (_maxY - _minY) * factor;
            
            final centerX = (_minX + _maxX) / 2;
            final centerY = (_minY + _maxY) / 2;
            
            _minX = centerX - rangeX / 2;
            _maxX = centerX + rangeX / 2;
            _minY = centerY - rangeY / 2;
            _maxY = centerY + rangeY / 2;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return LineChart(
              LineChartData(
                minX: _minX,
                maxX: _maxX,
                minY: _minY,
                maxY: _maxY,
                clipData: const FlClipData.all(),
                
                // Grid
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: (_maxY - _minY) / 5,
                  verticalInterval: (_maxX - _minX) / 6,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF334155),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  getDrawingVerticalLine: (value) => const FlLine(
                    color: Color(0xFF1E293B),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                
                // Border
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Color(0xFF475569)),
                    bottom: BorderSide(color: Color(0xFF475569)),
                  ),
                ),
                
                // X Axis (Time)
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  
                  // Bottom (Time)
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: (_maxX - _minX) / 6,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        final isLongRange = widget.toDate.difference(widget.fromDate).inDays > 2;
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isLongRange
                                ? PersianUtils.formatShortDate(date)
                                : PersianUtils.formatTime(date),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Left (Values)
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: (_maxY - _minY) / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          PersianUtils.formatNumber(value, decimals: 1),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Touch handling
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipBorder: const BorderSide(color: Color(0xFF475569)),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final series = visibleSeries[spot.barIndex];
                        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                        return LineTooltipItem(
                          '${series.label}\n'
                          '${PersianUtils.formatNumber(spot.y)} ${series.unit}\n'
                          '${PersianUtils.formatDateTime(date)}',
                          TextStyle(
                            color: series.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                      } else {
                      }
                    });
                  },
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        const FlLine(
                          color: Colors.white24,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: bar.color ?? Colors.blue,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
                
                // Lines
                lineBarsData: visibleSeries.asMap().entries.map((entry) {
                  final series = entry.value;
                  
                  // Downsample if too many points
                  final points = _downsamplePoints(series.points, maxPoints: 500);
                  
                  return LineChartBarData(
                    spots: points.map((p) {
                      return FlSpot(
                        p.timestamp.millisecondsSinceEpoch.toDouble(),
                        p.value * _animation.value,
                      );
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: series.color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: points.length < 50,
                      getDotPainter: (spot, percent, bar, index) {
                        final isMinMax = _isMinOrMax(series, spot.y / _animation.value);
                        return FlDotCirclePainter(
                          radius: isMinMax ? 5 : 3,
                          color: isMinMax ? Colors.white : series.color,
                          strokeWidth: isMinMax ? 2 : 1,
                          strokeColor: isMinMax ? series.color : Colors.white54,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          series.color.withValues(alpha: 0.3),
                          series.color.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    shadow: Shadow(
                      color: series.color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  );
                }).toList(),
                
                // Extra lines for min/max markers
                extraLinesData: ExtraLinesData(
                  horizontalLines: _buildMinMaxLines(visibleSeries),
                ),
              ),
              duration: const Duration(milliseconds: 300),
            );
          },
        ),
      ),
    );
  }

  bool _isMinOrMax(ChartSeriesData series, double value) {
    if (series.points.isEmpty) return false;
    return value == series.minValue || value == series.maxValue;
  }

  List<HorizontalLine> _buildMinMaxLines(List<ChartSeriesData> visibleSeries) {
    final lines = <HorizontalLine>[];
    
    for (final series in visibleSeries) {
      if (series.points.isEmpty) continue;
      
      // Min line
      lines.add(HorizontalLine(
        y: series.minValue,
        color: series.color.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [8, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: TextStyle(color: series.color, fontSize: 9),
          labelResolver: (line) => 'حداقل: ${PersianUtils.formatNumber(line.y)}',
        ),
      ));
      
      // Max line
      lines.add(HorizontalLine(
        y: series.maxValue,
        color: series.color.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [8, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          style: TextStyle(color: series.color, fontSize: 9),
          labelResolver: (line) => 'حداکثر: ${PersianUtils.formatNumber(line.y)}',
        ),
      ));
    }
    
    return lines;
  }

  List<ChartDataPoint> _downsamplePoints(List<ChartDataPoint> points, {int maxPoints = 500}) {
    if (points.length <= maxPoints) return points;
    
    final step = points.length / maxPoints;
    final result = <ChartDataPoint>[];
    
    for (var i = 0.0; i < points.length; i += step) {
      result.add(points[i.floor()]);
    }
    
    // Always include last point
    if (result.last != points.last) {
      result.add(points.last);
    }
    
    return result;
  }

  Widget _buildCrosshair() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _CrosshairPainter(_crosshairPosition!),
        ),
      ),
    );
  }

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
              Container(width: 8, height: 8, decoration: BoxDecoration(color: series.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                '${series.label}: ',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              Text(
                'حداقل: ${PersianUtils.formatNumber(series.minValue)} | ',
                style: const TextStyle(color: Colors.cyan, fontSize: 10),
              ),
              Text(
                'حداکثر: ${PersianUtils.formatNumber(series.maxValue)} | ',
                style: const TextStyle(color: Colors.orange, fontSize: 10),
              ),
              Text(
                'میانگین: ${PersianUtils.formatNumber(series.avgValue)}',
                style: const TextStyle(color: Colors.green, fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ============ EXPORT FUNCTIONS ============

  Future<Uint8List?> _captureChart() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart: $e');
      return null;
    }
  }

  Future<void> _exportAsImage() async {
    final imageBytes = await _captureChart();
    if (imageBytes == null) {
      _showError('خطا در ایجاد تصویر');
      return;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chart_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'نمودار گزارش SCADA',
      );
    } catch (e) {
      _showError('خطا در ذخیره تصویر: $e');
    }
  }

  Future<void> _exportAsPdf() async {
    setState(() => _isExporting = true);
    
    try {
      final imageBytes = await _captureChart();
      if (imageBytes == null) {
        _showError('خطا در ایجاد تصویر');
        return;
      }
      
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E293B'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        widget.title,
                        style: const pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '${PersianUtils.formatFull(widget.fromDate)} - ${PersianUtils.formatFull(widget.toDate)}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey400,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                
                // Chart image
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
                
                pw.SizedBox(height: 16),
                
                // Stats table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF334155)),
                      children: [
                        _pdfCell('واحد', header: true),
                        _pdfCell('میانگین', header: true),
                        _pdfCell('حداکثر', header: true),
                        _pdfCell('حداقل', header: true),
                        _pdfCell('تگ', header: true),
                      ],
                    ),
                    // Data rows
                    ...widget.seriesList.where((s) => s.isVisible).map((series) {
                      return pw.TableRow(
                        children: [
                          _pdfCell(series.unit),
                          _pdfCell(PersianUtils.formatNumber(series.avgValue)),
                          _pdfCell(PersianUtils.formatNumber(series.maxValue)),
                          _pdfCell(PersianUtils.formatNumber(series.minValue)),
                          _pdfCell(series.label),
                        ],
                      );
                    }),
                  ],
                ),
                
                pw.SizedBox(height: 16),
                
                // Footer
                pw.Text(
                  'تاریخ تولید: ${PersianUtils.formatDateTime(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            );
          },
        ),
      );
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'گزارش PDF - SCADA',
      );
      
    } catch (e) {
      _showError('خطا در ایجاد PDF: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _printChart() async {
    setState(() => _isExporting = true);
    
    try {
      final imageBytes = await _captureChart();
      if (imageBytes == null) {
        _showError('خطا در ایجاد تصویر');
        return;
      }
      
      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();
          final image = pw.MemoryImage(imageBytes);
          
          pdf.addPage(
            pw.Page(
              pageFormat: format,
              build: (context) => pw.Center(child: pw.Image(image)),
            ),
          );
          
          return pdf.save();
        },
      );
    } catch (e) {
      _showError('خطا در چاپ: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _shareChart() async {
    final imageBytes = await _captureChart();
    if (imageBytes == null) {
      _showError('خطا در ایجاد تصویر');
      return;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chart_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'نمودار گزارش SCADA\n'
              'بازه: ${PersianUtils.formatFull(widget.fromDate)} تا ${PersianUtils.formatFull(widget.toDate)}',
      );
    } catch (e) {
      _showError('خطا در اشتراک‌گذاری: $e');
    }
  }

  pw.Widget _pdfCell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 11 : 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.grey800,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Crosshair painter
class _CrosshairPainter extends CustomPainter {
  final Offset position;
  
  _CrosshairPainter(this.position);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    
    // Vertical line
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      paint,
    );
    
    // Horizontal line
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
