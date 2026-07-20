import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../utils/persian_utils.dart';

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
          child: widget.alarms.isEmpty
              ? _buildEmptyState()
              : _filteredAlarms.isEmpty
                  ? const Center(child: Text('نتیجه‌ای یافت نشد', style: TextStyle(color: Colors.white38)))
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh ?? () async {},
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredAlarms.length,
                        itemBuilder: (context, index) => _buildAlarmCard(_filteredAlarms[index]),
                      ),
                    ),
        ),
      ],
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
          ElevatedButton.icon(
            onPressed: _exportAsPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
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

  Future<void> _exportAsPdf() async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => [
            pw.Text('گزارش آلارم‌ها', style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF334155)),
                  children: ['وضعیت', 'حد مجاز', 'مقدار', 'نوع', 'تگ', 'زمان'].map((h) => 
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center),
                    )
                  ).toList(),
                ),
                ..._filteredAlarms.map((a) => pw.TableRow(
                  children: [
                    a.acknowledged ? 'تأیید شده' : 'فعال',
                    PersianUtils.formatNumber(a.threshold),
                    PersianUtils.formatNumber(a.value),
                    a.alarmTypeLabel,
                    a.tag,
                    PersianUtils.formatDateTime(a.createdAt),
                  ].map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(c, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                  )).toList(),
                )),
              ],
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alarms_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'گزارش آلارم‌ها');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red),
      );
    }
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
