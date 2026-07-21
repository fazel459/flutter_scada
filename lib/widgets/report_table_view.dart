import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scada/services/report_export_service.dart';
import '../utils/persian_utils.dart';

/// مدل داده جدول
class TableRowData {
  final String tag;
  final double value;
  final String unit;
  final DateTime timestamp;
  final double? minThreshold;
  final double? maxThreshold;
  bool isSelected;

  TableRowData({
    required this.tag,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.minThreshold,
    this.maxThreshold,
    this.isSelected = false,
  });

  bool get isAlarm {
    if (minThreshold != null && value < minThreshold!) return true;
    if (maxThreshold != null && value > maxThreshold!) return true;
    return false;
  }
}

class ReportTableView extends StatefulWidget {
  final List<Map<String, dynamic>> seriesData;
  final Function(List<TableRowData>)? onExport;

  const ReportTableView({
    super.key,
    required this.seriesData,
    this.onExport,
  });

  @override
  State<ReportTableView> createState() => _ReportTableViewState();
}

class _ReportTableViewState extends State<ReportTableView> {
  List<TableRowData> _allRows = [];
  List<TableRowData> _filteredRows = [];

  // صفحه‌بندی
  int _currentPage = 0;
  int _rowsPerPage = 50;

  // مرتب‌سازی
  String _sortColumn = 'timestamp';
  bool _sortAsc = false;

  // فیلتر
  String _searchQuery = '';
  String? _selectedTag;
  double? _minValueFilter;
  double? _maxValueFilter;
  bool _showOnlyAlarms = false;

  // انتخاب
  bool _selectAll = false;
  bool _isExporting = false;

  final _searchController = TextEditingController();
  final _minValueController = TextEditingController();
  final _maxValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buildRows();
  }

  @override
  void didUpdateWidget(ReportTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesData != widget.seriesData) {
      _buildRows();
    }
  }

  // ═══════════════ چاپ و خروجی ═══════════════

  /// اگر ردیفی انتخاب شده → همان‌ها، وگرنه → کل جدول فیلترشده
  List<TableRowData> _rowsToExport() {
    final selected = _filteredRows.where((r) => r.isSelected).toList();
    return selected.isNotEmpty ? selected : _filteredRows;
  }

  Future<void> _printTable() async {
    final rows = _rowsToExport();
    if (rows.isEmpty) {
      _showMsg('ردیفی برای چاپ وجود ندارد', error: true);
      return;
    }
    try {
      await ReportExportService.printTable(rows);
    } catch (e) {
      _showMsg('خطا در چاپ: $e', error: true);
    }
  }

  Future<void> _exportPdf() async {
    final rows = _rowsToExport();
    if (rows.isEmpty) {
      _showMsg('داده‌ای برای PDF وجود ندارد', error: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final path = await ReportExportService.savePdf(rows);
      if (path != null) {
        _showMsg('PDF ذخیره شد:\n$path');
      } else {
        _showMsg('PDF آماده ارسال شد');
      }
    } catch (e) {
      _showMsg('خطا در ایجاد PDF: $e', error: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv() async {
    final rows = _rowsToExport();
    if (rows.isEmpty) {
      _showMsg('داده‌ای برای CSV وجود ندارد', error: true);
      return;
    }
    try {
      final path = await ReportExportService.saveCsv(rows);
      if (path != null) {
        _showMsg('CSV ذخیره شد:\n$path');
      } else {
        _showMsg('CSV در کلیپ‌بورد کپی شد — در اکسل Paste کنید');
      }
    } catch (e) {
      _showMsg('خطا در ایجاد CSV: $e', error: true);
    }
  }

  void _showMsg(String message, {bool error = false}) {
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

  // ═══════════════ Toolbar ═══════════════

  Widget _buildToolbar() {
    final selectedCount = _filteredRows.where((r) => r.isSelected).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_chart, color: Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 8),
          const Text(
            'جدول داده‌ها',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 10),

          // تعداد نتایج
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${PersianUtils.formatInt(_filteredRows.length)} ردیف',
              style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  color: Color(0xFF3B82F6),
                  fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),

          // محدوده خروجی — با انتخاب ردیف، زنده تغییر می‌کند
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(selectedCount),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selectedCount > 0
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                selectedCount > 0
                    ? 'خروجی: ${PersianUtils.toPersian(selectedCount)} ردیف انتخابی'
                    : 'خروجی: همه ردیف‌ها',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 10,
                  color: selectedCount > 0
                      ? Colors.green
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          const Spacer(),

          // ── دکمه‌های خروجی ──
          _actionButton(Icons.print, 'چاپ جدول', _printTable),
          const SizedBox(width: 6),
          _actionButton(
            Icons.picture_as_pdf,
            'خروجی PDF',
            _exportPdf,
            showSpinner: _isExporting,
          ),
          const SizedBox(width: 6),
          _actionButton(Icons.table_chart_outlined, 'خروجی CSV', _exportCsv),
        ],
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
                      strokeWidth: 2, color: Colors.white70),
                )
              : Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  void _buildRows() {
    _allRows = [];
    for (final s in widget.seriesData) {
      final points = s['dataPoints'] as List? ?? [];
      final label = s['widgetLabel'] ?? '?';
      final unit = s['unit'] ?? '';

      for (final p in points) {
        _allRows.add(TableRowData(
          tag: label,
          value: (p['value'] as num).toDouble(),
          unit: unit,
          timestamp: DateTime.parse(p['timestamp'] as String),
          // می‌توانید threshold را از داده‌ها بخوانید
          minThreshold: s['lowAlarm'] as double?,
          maxThreshold: s['highAlarm'] as double?,
        ));
      }
    }
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    _filteredRows = _allRows.where((row) {
      // فیلتر جستجو
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!row.tag.toLowerCase().contains(query)) return false;
      }

      // فیلتر تگ
      if (_selectedTag != null && row.tag != _selectedTag) return false;

      // فیلتر مقدار
      if (_minValueFilter != null && row.value < _minValueFilter!) return false;
      if (_maxValueFilter != null && row.value > _maxValueFilter!) return false;

      // فیلتر آلارم
      if (_showOnlyAlarms && !row.isAlarm) return false;

      return true;
    }).toList();

    // مرتب‌سازی
    _filteredRows.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'tag':
          cmp = a.tag.compareTo(b.tag);
          break;
        case 'value':
          cmp = a.value.compareTo(b.value);
          break;
        case 'unit':
          cmp = a.unit.compareTo(b.unit);
          break;
        default:
          cmp = a.timestamp.compareTo(b.timestamp);
      }
      return _sortAsc ? cmp : -cmp;
    });

    // ریست صفحه
    _currentPage = 0;
    setState(() {});
  }

  List<String> get _uniqueTags {
    return _allRows.map((r) => r.tag).toSet().toList()..sort();
  }

  int get _totalPages => (_filteredRows.length / _rowsPerPage).ceil();

  List<TableRowData> get _currentPageRows {
    final start = _currentPage * _rowsPerPage;
    final end = math.min(start + _rowsPerPage, _filteredRows.length);
    if (start >= _filteredRows.length) return [];
    return _filteredRows.sublist(start, end);
  }

  int get _selectedCount => _filteredRows.where((r) => r.isSelected).length;

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = column;
        _sortAsc = true;
      }
      _applyFiltersAndSort();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (final row in _currentPageRows) {
        row.isSelected = _selectAll;
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'کپی شد: $text',
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportSelected() {
    final selected = _filteredRows.where((r) => r.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
              'هیچ ردیفی انتخاب نشده',
              style: TextStyle(fontFamily: 'Vazirmatn'),
            ),
            backgroundColor: Colors.orange),
      );
      return;
    }
    widget.onExport?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_allRows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_chart_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 12),
            Text(
              'داده‌ای برای نمایش وجود ندارد',
              style: TextStyle(color: Colors.white38, fontFamily: 'Vazirmatn'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        // نوار فیلتر
        _buildFilterBar(),

        // هدر جدول (ثابت)
        _buildTableHeader(),

        // ردیف‌های جدول
        Expanded(
          child: Stack(
            children: [
              _buildTableBody(),
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

        // نوار صفحه‌بندی
        _buildPaginationBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          // ردیف اول: جستجو و فیلتر تگ
          Row(
            children: [
              // جستجو
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'جستجو در تگ‌ها...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF64748B), size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _applyFiltersAndSort();
                            },
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                  ),
                  onChanged: (v) {
                    _searchQuery = v;
                    _applyFiltersAndSort();
                  },
                ),
              ),

              const SizedBox(width: 12),

              // فیلتر تگ
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedTag,
                      isExpanded: true,
                      hint: const Text('همه تگ‌ها',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'همه تگ‌ها',
                            style: TextStyle(
                                fontFamily: 'Vazirmatn', fontSize: 12),
                          ),
                        ),
                        ..._uniqueTags.map(
                            (t) => DropdownMenuItem(value: t, child: Text(t))),
                      ],
                      onChanged: (v) {
                        _selectedTag = v;
                        _applyFiltersAndSort();
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // فیلتر آلارم
              FilterChip(
                label: const Text('فقط آلارم‌ها',
                    style: TextStyle(fontSize: 10, fontFamily: 'Vazirmatn')),
                selected: _showOnlyAlarms,
                onSelected: (v) {
                  _showOnlyAlarms = v;
                  _applyFiltersAndSort();
                },
                selectedColor: Colors.red.withValues(alpha: 0.3),
                checkmarkColor: Colors.red,
                backgroundColor: Colors.black26,
                side: BorderSide(
                    color:
                        _showOnlyAlarms ? Colors.red : const Color(0xFF475569)),
                labelStyle: TextStyle(
                    color: _showOnlyAlarms ? Colors.red : Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ردیف دوم: فیلتر مقدار و اکشن‌ها
          Row(
            children: [
              // حداقل مقدار
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _minValueController,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'حداقل مقدار',
                    hintStyle:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    _minValueFilter = double.tryParse(v);
                    _applyFiltersAndSort();
                  },
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('تا',
                    style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'Vazirmatn')),
              ),

              // حداکثر مقدار
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _maxValueController,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'حداکثر مقدار',
                    hintStyle:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    _maxValueFilter = double.tryParse(v);
                    _applyFiltersAndSort();
                  },
                ),
              ),

              const Spacer(),

              // تعداد نتایج
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${PersianUtils.formatInt(_filteredRows.length)} نتیجه',
                  style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontFamily: 'Vazirmatn'),
                ),
              ),

              const SizedBox(width: 8),

              // انتخاب شده
              if (_selectedCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${PersianUtils.formatInt(_selectedCount)} انتخاب',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontFamily: 'Vazirmatn'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _exportSelected,
                  icon: const Icon(Icons.file_download, size: 16),
                  label: const Text('خروجی',
                      style: TextStyle(fontSize: 11, fontFamily: 'Vazirmatn')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF334155),
        border: Border(bottom: BorderSide(color: Color(0xFF475569))),
      ),
      child: Row(
        children: [
          // چک‌باکس انتخاب همه
          SizedBox(
            width: 40,
            child: Checkbox(
              value: _selectAll,
              onChanged: (_) => _toggleSelectAll(),
              activeColor: Colors.blue,
              side: const BorderSide(color: Color(0xFF64748B)),
            ),
          ),

          // شماره ردیف
          const SizedBox(
            width: 50,
            child: Text('#',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazirmatn'),
                textAlign: TextAlign.center),
          ),

          // ستون‌های قابل مرتب‌سازی
          _buildSortableHeader('زمان', 'timestamp', flex: 3),
          _buildSortableHeader('تگ', 'tag', flex: 2),
          _buildSortableHeader('مقدار', 'value', flex: 2),
          _buildSortableHeader('واحد', 'unit', flex: 1),

          // وضعیت
          const SizedBox(
            width: 60,
            child: Text(
              'وضعیت',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Vazirmatn'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String label, String column, {int flex = 1}) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _toggleSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blue : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableBody() {
    final rows = _currentPageRows;

    if (rows.isEmpty) {
      return const Center(
        child: Text('نتیجه‌ای یافت نشد',
            style: TextStyle(color: Colors.white38, fontFamily: 'Vazirmatn')),
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final globalIndex = _currentPage * _rowsPerPage + index + 1;

        return InkWell(
          onTap: () {
            setState(() {
              row.isSelected = !row.isSelected;
              _selectAll = _currentPageRows.every((r) => r.isSelected);
            });
          },
          onLongPress: () => _showRowOptions(row),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: row.isSelected
                  ? Colors.blue.withValues(alpha: 0.1)
                  : row.isAlarm
                      ? Colors.red.withValues(alpha: 0.05)
                      : index.isEven
                          ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                          : Colors.transparent,
              border: Border(
                bottom: const BorderSide(color: Color(0xFF334155), width: 0.5),
                right: row.isAlarm
                    ? const BorderSide(color: Colors.red, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                // چک‌باکس
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: row.isSelected,
                    onChanged: (_) {
                      setState(() {
                        row.isSelected = !row.isSelected;
                        _selectAll =
                            _currentPageRows.every((r) => r.isSelected);
                      });
                    },
                    activeColor: Colors.blue,
                    side: const BorderSide(color: Color(0xFF64748B)),
                  ),
                ),

                // شماره ردیف
                SizedBox(
                  width: 50,
                  child: Text(
                    PersianUtils.toPersian(globalIndex),
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontFamily: 'Vazirmatn'),
                    textAlign: TextAlign.center,
                  ),
                ),

                // زمان
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onLongPress: () => _copyToClipboard(
                        PersianUtils.formatDateTime(row.timestamp)),
                    child: Text(
                      PersianUtils.formatDateTime(row.timestamp),
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),

                // تگ
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onLongPress: () => _copyToClipboard(row.tag),
                    child: Text(
                      row.tag,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // مقدار
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onLongPress: () => _copyToClipboard(row.value.toString()),
                    child: Text(
                      PersianUtils.formatNumber(row.value),
                      style: TextStyle(
                        color: row.isAlarm ? Colors.red : Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                // واحد
                Expanded(
                  flex: 1,
                  child: Text(
                    row.unit,
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
                ),

                // وضعیت
                SizedBox(
                  width: 60,
                  child: row.isAlarm
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, size: 12, color: Colors.red),
                              SizedBox(width: 2),
                              Text('آلارم',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 9,
                                      fontFamily: 'Vazirmatn')),
                            ],
                          ),
                        )
                      : const Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRowOptions(TableRowData row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('کپی مقدار',
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
              onTap: () {
                _copyToClipboard(row.value.toString());
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all, color: Colors.white70),
              title: const Text('کپی کامل ردیف',
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
              onTap: () {
                _copyToClipboard(
                    '${row.tag}: ${row.value} ${row.unit} - ${PersianUtils.formatDateTime(row.timestamp)}');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_alt, color: Colors.white70),
              title: const Text('فیلتر بر این تگ',
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
              onTap: () {
                Navigator.pop(context);
                _selectedTag = row.tag;
                _applyFiltersAndSort();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          // تعداد در صفحه
          const Text('تعداد در صفحه:',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontFamily: 'Vazirmatn')),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              items: [25, 50, 100, 200]
                  .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text(PersianUtils.toPersian(n)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _rowsPerPage = v;
                  _currentPage = 0;
                  setState(() {});
                }
              },
            ),
          ),

          const Spacer(),

          // شماره صفحه
          Text(
            'صفحه ${PersianUtils.toPersian(_currentPage + 1)} از ${PersianUtils.toPersian(_totalPages)}',
            style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Vazirmatn',
                fontSize: 11),
          ),

          const SizedBox(width: 16),

          // دکمه‌های ناوبری
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage = 0)
                : null,
            icon: const Icon(Icons.first_page),
            color: Colors.white70,
            disabledColor: Colors.white24,
            iconSize: 20,
            tooltip: 'صفحه اول',
          ),
          IconButton(
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white70,
            disabledColor: Colors.white24,
            iconSize: 20,
            tooltip: 'صفحه قبل',
          ),
          IconButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white70,
            disabledColor: Colors.white24,
            iconSize: 20,
            tooltip: 'صفحه بعد',
          ),
          IconButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage = _totalPages - 1)
                : null,
            icon: const Icon(Icons.last_page),
            color: Colors.white70,
            disabledColor: Colors.white24,
            iconSize: 20,
            tooltip: 'صفحه آخر',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }
}
