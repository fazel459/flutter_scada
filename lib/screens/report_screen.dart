// ignore_for_file: curly_braces_in_flow_control_structures, unused_import

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/utils/persian-datetime-picker/lib/persian_datetime_picker.dart';
import 'package:flutter_scada/utils/persian_utils.dart';
import 'package:flutter_scada/utils/shamsi_date/lib/shamsi_date.dart';
import 'package:flutter_scada/widgets/persian_chart.dart';
import 'package:flutter_scada/widgets/persian_date_range_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/providers.dart';
import '../services/api_service.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String? pageId;
  const ReportScreen({super.key, this.pageId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  // انتخاب تگ‌ها
  List<Map<String, dynamic>> _allTags = [];
  Set<String> _selectedTagIds = {};
  bool _tagsLoading = true;

  // بازه زمانی
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  String _quickRange = '7d';

  // داده‌های گزارش
  Map<String, dynamic>? _reportData;
  bool _dataLoading = false;
  String? _error;

  // تنظیمات
  String _aggregateMode = 'none'; // none, avg, min, max
  int _intervalMinutes = 5;
  String _viewMode = 'table'; // table, chart, stats

  // مرتب‌سازی
  String _sortColumn = 'timestamp';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _tagsLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/reports/tags');
      setState(() {
        _allTags = List<Map<String, dynamic>>.from(res['tags'] ?? []);
        _tagsLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tags: $e';
        _tagsLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (_selectedTagIds.isEmpty) return;

    setState(() {
      _dataLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/reports/data', {
        'widgetIds': _selectedTagIds.toList(),
        'from': _fromDate.toIso8601String(),
        'to': _toDate.toIso8601String(),
        'interval': _aggregateMode == 'none' ? null : _intervalMinutes * 60000,
        'aggregate': _aggregateMode == 'none' ? null : _aggregateMode,
      });
      setState(() {
        _reportData = res;
        _dataLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _dataLoading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_selectedTagIds.isEmpty) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/reports/export', {
        'widgetIds': _selectedTagIds.toList(),
        'from': _fromDate.toIso8601String(),
        'to': _toDate.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV export started'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _setQuickRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case '1h':
        _fromDate = now.subtract(const Duration(hours: 1));
        break;
      case '6h':
        _fromDate = now.subtract(const Duration(hours: 6));
        break;
      case '24h':
        _fromDate = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        _fromDate = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        _fromDate = now.subtract(const Duration(days: 30));
        break;
      case '90d':
        _fromDate = now.subtract(const Duration(days: 90));
        break;
    }
    _toDate = now;
    _quickRange = range;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📊 Reports',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
              icon: const Icon(Icons.file_download, color: Colors.white70),
              onPressed: _exportCsv,
              tooltip: 'Export CSV'),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _loadData,
              tooltip: 'Refresh'),
        ],
      ),
      body: Row(
        children: [
          // ====== پنل سمت چپ: انتخاب تگ و تنظیمات ======
          _buildSidePanel(),

          // ====== محتوای اصلی: جدول / چارت / آمار ======
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  // ============ SIDE PANEL ============
  Widget _buildSidePanel() {
    return Container(
      width: 300,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF334155)))),
            child: Row(
              children: [
                const Icon(Icons.label, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                const Text('Select Tags',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const Spacer(),
                Text('${_selectedTagIds.length}/${_allTags.length}',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),

          // Search & Select all
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search tags...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFF475569))),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF64748B), size: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedTagIds.length == _allTags.length) {
                        _selectedTagIds.clear();
                      } else {
                        _selectedTagIds = _allTags
                            .map((t) => t['widgetId'] as String)
                            .toSet();
                      }
                    });
                  },
                  child: Text(
                      _selectedTagIds.length == _allTags.length
                          ? 'None'
                          : 'All',
                      style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),

          // Tag list
          Expanded(
            child: _tagsLoading
                ? const Center(child: CircularProgressIndicator())
                : _allTags.isEmpty
                    ? const Center(
                        child: Text('No tags found',
                            style: TextStyle(color: Color(0xFF64748B))))
                    : ListView.builder(
                        itemCount: _allTags.length,
                        itemBuilder: (ctx, i) {
                          final tag = _allTags[i];
                          final id = tag['widgetId'] as String;
                          final selected = _selectedTagIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedTagIds.add(id);
                                } else {
                                  _selectedTagIds.remove(id);
                                }
                              });
                            },
                            title: Text(tag['widgetLabel'] ?? 'Unknown',
                                style: TextStyle(
                                    color:
                                        selected ? Colors.blue : Colors.white70,
                                    fontSize: 12)),
                            subtitle: tag['pageTitle'] != null
                                ? Text(tag['pageTitle'] as String,
                                    style: const TextStyle(
                                        color: Color(0xFF64748B), fontSize: 9))
                                : null,
                            activeColor: Colors.blue,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          );
                        },
                      ),
          ),

          // Time Range Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF334155)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.white54, size: 14),
                    SizedBox(width: 6),
                    Text('بازه زمانی',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),

                const SizedBox(height: 8),
                PersianDateRangePicker(
                  fromDate: _fromDate,
                  toDate: _toDate,
                  onRangeChanged: (from, to) {
                    setState(() {
                      _fromDate = from!;
                      _toDate = to!;
                    });
                  },
                ),
                // Quick buttons
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ['1h', '6h', '24h', '7d', '30d', '90d'].map((r) {
                    final active = _quickRange == r;
                    return GestureDetector(
                      onTap: () => _setQuickRange(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: active
                                  ? Colors.blue
                                  : const Color(0xFF475569)),
                        ),
                        child: Text(r,
                            style: TextStyle(
                                color: active
                                    ? Colors.blue
                                    : const Color(0xFF94A3B8),
                                fontSize: 10)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),

                // Date pickers
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                          'From',
                          _fromDate,
                          (d) => setState(() {
                                if (d.isBefore(DateTime.now())) {
                                  _fromDate = d;
                                  _quickRange = '';
                                }
                              })),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _dateButton(
                          'To',
                          _toDate,
                          (d) => setState(() {
                                if (d.isBefore(DateTime.now()) || d.isAtSameMomentAs(DateTime.now())) {
                                  _toDate = d;
                                  _quickRange = '';
                                }
                              })),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Aggregate mode
                Row(
                  children: [
                    const Text('Aggregate:',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _aggregateMode,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('Raw')),
                            DropdownMenuItem(
                                value: 'avg', child: Text('Average')),
                            DropdownMenuItem(value: 'min', child: Text('Min')),
                            DropdownMenuItem(value: 'max', child: Text('Max')),
                          ],
                          onChanged: (v) =>
                              setState(() => _aggregateMode = v ?? 'none'),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_aggregateMode != 'none') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Interval:',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _intervalMinutes,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 min')),
                              DropdownMenuItem(value: 5, child: Text('5 min')),
                              DropdownMenuItem(
                                  value: 15, child: Text('15 min')),
                              DropdownMenuItem(
                                  value: 30, child: Text('30 min')),
                              DropdownMenuItem(
                                  value: 60, child: Text('1 hour')),
                              DropdownMenuItem(
                                  value: 360, child: Text('6 hours')),
                              DropdownMenuItem(
                                  value: 1440, child: Text('24 hours')),
                            ],
                            onChanged: (v) =>
                                setState(() => _intervalMinutes = v ?? 5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Generate button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed:
                  _selectedTagIds.isEmpty || _dataLoading ? null : _loadData,
              icon: _dataLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(
      String label, DateTime date, Function(DateTime) onChanged) {
    return GestureDetector(
      onTap: () async {
        Jalali? picked = await showPersianDatePicker(
          context: context,
          initialDate: Jalali.now(),
          firstDate: Jalali(1385, 8),
          lastDate: Jalali(1450, 9),
          holidayConfig: const PersianHolidayConfig(weekendDays: {7}),
          initialEntryMode: PersianDatePickerEntryMode.calendarOnly,
          initialDatePickerMode: PersianDatePickerMode.year,
        );
        if (picked != null &&
            (picked.toDateTime().isBefore(DateTime.now()) ||
                picked.toDateTime().isAtSameMomentAs(DateTime.now()))) {
          DateTime d = picked.toDateTime();

          onChanged(DateTime(d.year, d.month, d.day));

          var timePicked = await showTimePicker(
            // ignore: use_build_context_synchronously
            context: context,
            initialTime: TimeOfDay.now(),
            initialEntryMode: TimePickerEntryMode.input,
            builder: (BuildContext context, Widget? child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
            },
          );

          if (timePicked != null) {
            final pickedDateTime = DateTime(
                d.year, d.month, d.day, timePicked.hour, timePicked.minute);
            onChanged(pickedDateTime);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
            Text(PersianUtils.formatJalaliDateTime(date),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ============ MAIN CONTENT ============
  Widget _buildMainContent() {
    return Container(
      color: const Color(0xFF0A0F1A),
      child: Column(
        children: [
          // View toggle + Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                _viewToggle('📋', 'Table', 'table'),
                const SizedBox(width: 4),
                _viewToggle('📈', 'Chart', 'chart'),
                const SizedBox(width: 4),
                _viewToggle('📊', 'Stats', 'stats'),
                const Spacer(),
                if (_reportData != null)
                  Text(
                    '${_reportData!['totalPoints']} data points | ${(_reportData!['series'] as List?)?.length ?? 0} tags',
                    style:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      TextButton(
                          onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ))
                : _reportData == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.analytics_outlined,
                                color: Colors.white24, size: 64),
                            SizedBox(height: 12),
                            Text('Select tags and generate a report',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14)),
                          ],
                        ),
                      )
                    : _dataLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _viewMode == 'stats'
                            ? _buildStatsView()
                            : _viewMode == 'chart'
                                ? _buildChartViewNew()
                                : _buildTableView(),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle(String icon, String label, String mode) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              active ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active
                  ? Colors.blue.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Text('$icon $label',
            style: TextStyle(
                color: active ? Colors.blue : const Color(0xFF94A3B8),
                fontSize: 11)),
      ),
    );
  }

  // ============ TABLE VIEW ============
  Widget _buildTableView() {
    final series = (_reportData?['series'] as List<dynamic>?) ?? [];
    if (series.isEmpty)
      return const Center(
          child: Text('No data', style: TextStyle(color: Colors.white38)));

    // Flat list of all data points
    final allRows = <Map<String, dynamic>>[];
    for (final s in series) {
      final points = s['dataPoints'] as List<dynamic>? ?? [];
      for (final p in points) {
        allRows.add({
          'tag': s['widgetLabel'] ?? '?',
          'value': p['value'],
          'unit': s['unit'] ?? '',
          'timestamp': DateTime.parse(p['timestamp'] as String),
        });
      }
    }

    // Sort
    allRows.sort((a, b) {
      int cmp;
      if (_sortColumn == 'tag') {
        cmp = (a['tag'] as String).compareTo(b['tag'] as String);
      } else if (_sortColumn == 'value')
        cmp = ((a['value'] as double) - (b['value'] as double)).sign.toInt();
      else
        cmp =
            (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime);
      return _sortAsc ? cmp : -cmp;
    });

    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                _sortableHeader('Timestamp', 'timestamp', flex: 3),
                _sortableHeader('Tag', 'tag', flex: 3),
                _sortableHeader('Value', 'value', flex: 2),
                const SizedBox(
                    width: 50,
                    child: Text('Unit',
                        style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Rows
          ...allRows.map((row) => Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 300) * 0.375,
                      child: Text(
                          DateFormat('MM/dd HH:mm:ss')
                              .format(row['timestamp'] as DateTime),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontFamily: 'monospace')),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 300) * 0.375,
                      child: Text(row['tag'] as String,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 300) * 0.25,
                      child: Text(
                        (row['value'] as double).toStringAsFixed(2),
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(row['unit'] as String,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 10)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, String column, {int flex = 1}) {
    final active = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortColumn == column) {
              _sortAsc = !_sortAsc;
            } else {
              _sortColumn = column;
              _sortAsc = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: active ? Colors.blue : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            if (active)
              Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // ============ CHART VIEW ============
  // ignore: unused_element
  Widget _buildChartView() {
    final series = (_reportData?['series'] as List<dynamic>?) ?? [];
    if (series.isEmpty)
      return const Center(
          child: Text('No data', style: TextStyle(color: Colors.white38)));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: series.map((s) {
              final color = _chartColor(series.indexOf(s));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 3, color: color),
                  const SizedBox(width: 4),
                  Text('${s['widgetLabel']} (${s['unit']})',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Chart
          Expanded(
            child: CustomPaint(
              painter: _ReportChartPainter(series, _fromDate, _toDate),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildChartViewNew() {
  // Ensure _reportData is treated as a nullable List and fallback to empty list
  // final seriesData = (_reportData as List?) ?? [];
   final seriesData = (_reportData?['series'] as List?) ?? [];
  if (seriesData.isEmpty) {
    return const Center(
      child: Text("داده‌ای برای نمایش وجود ندارد", style: TextStyle(color: Colors.white38)),
    );
  }
  
  // تبدیل داده به فرمت چارت
  final chartSeries = <ChartSeriesData>[];
  final colors = [
    const Color(0xFF3B82F6),
    const Color(0xFF22C55E),
    const Color(0xFFEF4444),
    const Color(0xFFEAB308),
    const Color(0xFF8B5CF6),
    const Color(0xFF06B6D4),
    const Color(0xFFF97316),
    const Color(0xFFEC4899),
  ];
  
  for (var i = 0; i<  seriesData.length; i++) {
    final s = seriesData[i];
    final points = (s['dataPoints'] as List?)?.map((p) {
      return ChartDataPoint(
        timestamp: DateTime.parse(p['timestamp'] as String),
        value: (p['value'] as num).toDouble(),
      );
    }).toList() ?? [];
    
    chartSeries.add(ChartSeriesData(
      id: s['id'] ?? 'unknown',
      label: s['label'] ?? 'نامشخص',
      unit: s['unit'] ?? '',
      points: points,
      color: colors[i % colors.length],
    ));
  }
  
  return PersianChart(
    seriesList: chartSeries,
    fromDate: _fromDate,
    toDate: _toDate,
    title:"",
    onPointTap: (point, series) {
      // اختیاری: کاری انجام دهید وقتی روی نقطه کلیک شد
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${series.label}: ${PersianUtils.formatNumber(point.value)} ${series.unit}\n'
            '${PersianUtils.formatDateTime(point.timestamp)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    },
  );
}

  Color _chartColor(int index) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF22C55E),
      Color(0xFFEF4444),
      Color(0xFFEAB308),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFF97316),
      Color(0xFFEC4899)
    ];
    return colors[index % colors.length];
  }

  // ============ STATS VIEW ============
  Widget _buildStatsView() {
    final series = (_reportData?['series'] as List<dynamic>?) ?? [];
    if (series.isEmpty)
      return const Center(
          child: Text('No data', style: TextStyle(color: Colors.white38)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: series.map((s) {
        final points = s['dataPoints'] as List<dynamic>? ?? [];
        if (points.isEmpty) return const SizedBox();
        final values =
            points.map((p) => (p['value'] as num).toDouble()).toList();
        final total = values.fold(0.0, (a, b) => a + b);
        final avg = total / values.length;
        final min = values.reduce((a, b) => a < b ? a : b);
        final max = values.reduce((a, b) => a > b ? a : b);
        final first = DateTime.parse(points.first['timestamp'] as String);
        final last = DateTime.parse(points.last['timestamp'] as String);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏷️ ${s['widgetLabel']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const Divider(color: Color(0xFF334155)),
                _statRow('Count', '${points.length}'),
                _statRow(
                    'Average', '${avg.toStringAsFixed(2)} ${s['unit'] ?? ''}'),
                _statRow(
                    'Minimum', '${min.toStringAsFixed(2)} ${s['unit'] ?? ''}'),
                _statRow(
                    'Maximum', '${max.toStringAsFixed(2)} ${s['unit'] ?? ''}'),
                _statRow(
                    'Sum', '${total.toStringAsFixed(2)} ${s['unit'] ?? ''}'),
                _statRow('Range', (max - min).toStringAsFixed(2)),
                _statRow('From', DateFormat('yyyy/MM/dd HH:mm').format(first)),
                _statRow('To', DateFormat('yyyy/MM/dd HH:mm').format(last)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}

// ============ CHART PAINTER ============
class _ReportChartPainter extends CustomPainter {
  final List<dynamic> series;
  final DateTime from;
  final DateTime to;

  _ReportChartPainter(this.series, this.from, this.to);

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0A0F1A));

    const padding = EdgeInsets.fromLTRB(60, 10, 20, 40);
    final chartW = size.width - padding.left - padding.right;
    final chartH = size.height - padding.top - padding.bottom;

    // Grid
    for (int i = 0; i <= 5; i++) {
      final y = padding.top + chartH * i / 5;
      canvas.drawLine(
          Offset(padding.left, y),
          Offset(size.width - padding.right, y),
          Paint()..color = Colors.white.withValues(alpha: 0.08));
    }

    // Find global min/max
    double globalMin = double.infinity, globalMax = double.negativeInfinity;
    for (final s in series) {
      final pts = (s['dataPoints'] as List<dynamic>?) ?? [];
      for (final p in pts) {
        final v = (p['value'] as num).toDouble();
        if (v < globalMin) globalMin = v;
        if (v > globalMax) globalMax = v;
      }
    }

    final range = math.max(globalMax - globalMin, 1);
    final totalMs = to.difference(from).inMilliseconds.toDouble();

    for (var i = 0; i < series.length; i++) {
      final s = series[i];
      final color = _colors[i % _colors.length];
      final pts = (s['dataPoints'] as List<dynamic>?) ?? [];
      if (pts.isEmpty) continue;

      final path = Path();
      var first = true;

      for (final p in pts) {
        final v = (p['value'] as num).toDouble();
        final t = DateTime.parse(p['timestamp'] as String);
        final x = padding.left +
            chartW *
                (t.difference(from).inMilliseconds / totalMs).clamp(0.0, 1.0);
        final y = padding.top +
            chartH * (1 - ((v - globalMin) / range).clamp(0.0, 1.0));

        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }

      // Glow
      canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..strokeWidth = 4
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Line
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }

    // Labels
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 5; i++) {
      final val = globalMin + range * i / 5;
      labelPainter.text = TextSpan(
          text: val.toStringAsFixed(1),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 8));
      labelPainter.layout();
      final y = padding.top + chartH * (1 - i / 5);
      labelPainter.paint(
          canvas,
          Offset(padding.left - labelPainter.width - 6,
              y - labelPainter.height / 2));
    }

    // Time labels
    final df = DateFormat('MM/dd HH:mm');
    labelPainter.text = TextSpan(
        text: df.format(from),
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 8));
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(padding.left, size.height - 28));
    labelPainter.text = TextSpan(
        text: df.format(to),
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 8));
    labelPainter.layout();
    labelPainter.paint(
        canvas,
        Offset(
            size.width - padding.right - labelPainter.width, size.height - 28));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
