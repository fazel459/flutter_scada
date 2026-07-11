import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_model.dart';
import '../services/api_service.dart';
import '../providers/providers.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  List<Tag> _tags = [];
  List<TagGroup> _groups = [];
  String _selectedGroup = '';
  String _searchQuery = '';
  bool _loading = true;
  Set<String> _selectedIds = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final params = <String, dynamic>{};
      if (_selectedGroup.isNotEmpty) params['group'] = _selectedGroup;
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;

      final res = await api.get('/tags', params: params);
      final groupsRes = await api.get('/tags/groups');
      setState(() {
        _tags = (res['tags'] as List).map((t) => Tag.fromJson(t)).toList();
        _groups = (groupsRes['groups'] as List).map((g) => TagGroup(name: g['name'], count: g['count'])).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // ====== SIDEBAR: Groups ======
          Container(
            width: 200,
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF334155)))),
                  child: Row(
                    children: [
                      const Text('🏷️ Tag Groups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showAddGroupDialog,
                        child: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                      ),
                    ],
                  ),
                ),
                // All
                _groupItem('', 'All Tags', _tags.length),
                // Groups
                Expanded(
                  child: ListView(
                    children: _groups.map((g) => _groupItem(g.name, g.name, g.count)).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ====== MAIN CONTENT ======
          Expanded(
            child: Column(
              children: [
                // Toolbar
                _buildToolbar(),
                // Table
                Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildTable()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupItem(String key, String label, int count) {
    final selected = _selectedGroup == key;
    return GestureDetector(
      onTap: () { setState(() => _selectedGroup = key); _loadData(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: selected ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        child: Row(
          children: [
            Icon(key.isEmpty ? Icons.label : Icons.folder, size: 14, color: selected ? Colors.blue : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.blue : Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Text('🏷️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Tags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Text('${_tags.length} items', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(width: 16),
          // Search
          SizedBox(
            width: 200,
            height: 32,
            child: TextField(
              onChanged: (v) { _searchQuery = v; _loadData(); },
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search tags...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          const Spacer(),
          // Bulk actions
          if (_selectMode && _selectedIds.isNotEmpty) ...[
            _toolBtn(Icons.check_circle, 'Activate', Colors.green, () => _bulkAction('activate')),
            _toolBtn(Icons.block, 'Deactivate', Colors.orange, () => _bulkAction('deactivate')),
            _toolBtn(Icons.delete, 'Delete', Colors.red, () => _bulkAction('delete')),
            const SizedBox(width: 8),
          ],
          _toolBtn(Icons.checklist, _selectMode ? 'Done' : 'Select', _selectMode ? Colors.orange : Colors.white70, () {
            setState(() { _selectMode = !_selectMode; _selectedIds.clear(); });
          }),
          _toolBtn(Icons.file_download, 'Export', Colors.white70, _exportCsv),
          _toolBtn(Icons.add, 'New Tag', Colors.blue, () => _showTagEditor(null)),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_tags.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text('🏷️', style: TextStyle(fontSize: 48)), SizedBox(height: 8),
          Text('No tags found', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          Text('Click "+ New Tag" to create one', style: TextStyle(color: Color(0xFF475569), fontSize: 11))],
      ));
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
            dataRowColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? Colors.blue.withOpacity(0.1) : Colors.transparent),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
            dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
            columns: [
              if (_selectMode) const DataColumn(label: SizedBox(width: 24)),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Name')),
              const DataColumn(label: Text('Description')),
              const DataColumn(label: Text('Group')),
              const DataColumn(label: Text('Unit')),
              const DataColumn(label: Text('Protocol')),
              const DataColumn(label: Text('Range')),
              const DataColumn(label: Text('Last Value')),
              const DataColumn(label: Text('Quality')),
              const DataColumn(label: Text('Actions')),
            ],
            rows: _tags.map((tag) => DataRow(
              selected: _selectedIds.contains(tag.id),
              cells: [
                if (_selectMode) DataCell(Checkbox(
                  value: _selectedIds.contains(tag.id),
                  onChanged: (v) { setState(() { v == true ? _selectedIds.add(tag.id) : _selectedIds.remove(tag.id); }); },
                  activeColor: Colors.blue,
                )),
                DataCell(Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tag.isActive ? (tag.quality == SignalQuality.good ? Colors.green : tag.quality == SignalQuality.bad ? Colors.red : Colors.amber) : Colors.grey,
                  ),
                )),
                DataCell(Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(SizedBox(width: 150, child: Text(tag.description, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8))))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)),
                  child: Text(tag.group, style: const TextStyle(fontSize: 10)),
                )),
                DataCell(Text(tag.unit, style: const TextStyle(color: Color(0xFF94A3B8)))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _protocolColor(tag.protocol).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tag.protocol.label, style: TextStyle(fontSize: 9, color: _protocolColor(tag.protocol))),
                )),
                DataCell(Text('${tag.engMin.toStringAsFixed(0)} - ${tag.engMax.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8)))),
                DataCell(Text(
                  tag.lastValue?.toStringAsFixed(2) ?? '---',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: tag.lastValue != null ? Colors.blue : const Color(0xFF475569)),
                )),
                DataCell(_qualityBadge(tag.quality)),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.blue), onPressed: () => _showTagEditor(tag), constraints: const BoxConstraints(minWidth: 28, minHeight: 28), padding: EdgeInsets.zero),
                  IconButton(icon: const Icon(Icons.delete, size: 14, color: Colors.red), onPressed: () => _deleteTag(tag), constraints: const BoxConstraints(minWidth: 28, minHeight: 28), padding: EdgeInsets.zero),
                ])),
              ],
            )).toList(),
          ),
        ),
      ),
    );
  }

  Color _protocolColor(TagProtocol p) {
    switch (p) {
      case TagProtocol.mqtt: return Colors.green;
      case TagProtocol.modbusTcp: return Colors.blue;
      case TagProtocol.modbusRtu: return Colors.indigo;
      case TagProtocol.opcua: return Colors.purple;
      case TagProtocol.simulation: return Colors.amber;
    }
  }

  Widget _qualityBadge(SignalQuality q) {
    final Map<SignalQuality, (String, Color)> m = {
      SignalQuality.good: ('Good', Colors.green),
      SignalQuality.bad: ('Bad', Colors.red),
      SignalQuality.uncertain: ('?', Colors.amber),
      SignalQuality.unknown: ('N/A', const Color(0xFF475569)),
    };
    final (label, color) = m[q]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, color: color)),
    );
  }

  // ====== DIALOGS ======
  void _showTagEditor(Tag? existing) {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final groupCtrl = TextEditingController(text: existing?.group ?? 'Default');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    var protocol = existing?.protocol ?? TagProtocol.simulation;
    var dataType = existing?.dataType ?? TagDataType.analog;
    final engMinCtrl = TextEditingController(text: (existing?.engMin ?? 0).toString());
    final engMaxCtrl = TextEditingController(text: (existing?.engMax ?? 100).toString());
    final rawMinCtrl = TextEditingController(text: (existing?.rawMin ?? 0).toString());
    final rawMaxCtrl = TextEditingController(text: (existing?.rawMax ?? 65535).toString());
    final pollCtrl = TextEditingController(text: (existing?.pollInterval ?? 1000).toString());
    var alarmEnabled = existing?.alarmEnabled ?? false;
    final hiCtrl = TextEditingController(text: (existing?.highAlarm ?? 80).toString());
    final loCtrl = TextEditingController(text: (existing?.lowAlarm ?? 20).toString());
    var config = Map<String, dynamic>.from(existing?.protocolConfig ?? Tag.defaultConfig(protocol));
    int tabIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(isNew ? '➕ New Tag' : '✏️ Edit: ${existing!.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 500, height: 450,
          child: Column(
            children: [
              // Tabs
              Row(children: ['General', 'Data Source', 'Scaling', 'Alarms'].asMap().entries.map((e) =>
                Expanded(child: GestureDetector(
                  onTap: () => setD(() => tabIndex = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tabIndex == e.key ? Colors.blue : Colors.transparent, width: 2))),
                    child: Text(e.value, textAlign: TextAlign.center, style: TextStyle(color: tabIndex == e.key ? Colors.blue : const Color(0xFF94A3B8), fontSize: 11)),
                  ),
                )),
              ).toList()),
              const SizedBox(height: 12),
              // Tab content
              Expanded(
                child: SingleChildScrollView(
                  child: [
                    // 0: General
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _dField('Name *', nameCtrl),
                      _dField('Description', descCtrl),
                      _dField('Group', groupCtrl),
                      _dField('Unit', unitCtrl),
                      _dDropdown<TagDataType>('Data Type', dataType, TagDataType.values, (v) => setD(() => dataType = v), (v) => v.label),
                    ]),
                    // 1: Data Source
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _dDropdown<TagProtocol>('Protocol', protocol, TagProtocol.values, (v) { setD(() { protocol = v; config = Tag.defaultConfig(v); }); }, (v) => v.label),
                      _dField('Poll Interval (ms)', pollCtrl),
                      const Divider(color: Color(0xFF334155)),
                      ..._protocolFields(protocol, config, setD),
                    ]),
                    // 2: Scaling
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: _dField('Raw Min', rawMinCtrl)), const SizedBox(width: 8), Expanded(child: _dField('Raw Max', rawMaxCtrl))]),
                      Row(children: [Expanded(child: _dField('Eng Min', engMinCtrl)), const SizedBox(width: 8), Expanded(child: _dField('Eng Max', engMaxCtrl))]),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Text('Raw [${rawMinCtrl.text} - ${rawMaxCtrl.text}]', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          const Text(' → ', style: TextStyle(color: Colors.blue)),
                          Text('Eng [${engMinCtrl.text} - ${engMaxCtrl.text}]', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ]),
                    // 3: Alarms
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SwitchListTile(
                        title: const Text('Enable Alarms', style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: alarmEnabled,
                        onChanged: (v) => setD(() => alarmEnabled = v),
                        activeColor: Colors.blue, dense: true,
                      ),
                      if (alarmEnabled) ...[
                        Row(children: [Expanded(child: _dField('High Alarm', hiCtrl)), const SizedBox(width: 8), Expanded(child: _dField('Low Alarm', loCtrl))]),
                      ],
                    ]),
                  ][tabIndex],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isNew) TextButton(onPressed: () { Navigator.pop(ctx); _deleteTag(existing!); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final api = ref.read(apiServiceProvider);
              final body = {
                'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim(),
                'group': groupCtrl.text.trim(), 'unit': unitCtrl.text.trim(),
                'dataType': dataType.name, 'protocol': protocol.name, 'protocolConfig': config,
                'pollInterval': int.tryParse(pollCtrl.text) ?? 1000,
                'engMin': double.tryParse(engMinCtrl.text) ?? 0, 'engMax': double.tryParse(engMaxCtrl.text) ?? 100,
                'rawMin': double.tryParse(rawMinCtrl.text) ?? 0, 'rawMax': double.tryParse(rawMaxCtrl.text) ?? 65535,
                'alarmEnabled': alarmEnabled,
                'highAlarm': double.tryParse(hiCtrl.text) ?? 80, 'lowAlarm': double.tryParse(loCtrl.text) ?? 20,
              };
              if (isNew) { await api.post('/tags', body); } else { await api.put('/tags/${existing!.id}', body); }
              if (mounted) { Navigator.pop(ctx); _loadData(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(isNew ? 'Create' : 'Save'),
          ),
        ],
      )),
    );
  }

  Widget _dField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        const SizedBox(height: 2),
        SizedBox(height: 32, child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true, fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF475569))),
          ),
        )),
      ]),
    );
  }

  Widget _dDropdown<T>(String label, T value, List<T> items, Function(T) onChanged, String Function(T) labelFn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        const SizedBox(height: 2),
        DropdownButtonFormField<T>(
          value: value, isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true, fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF475569)))),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(labelFn(i)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ]),
    );
  }

  List<Widget> _protocolFields(TagProtocol p, Map<String, dynamic> config, void Function(void Function()) setD) {
    Widget f(String key, String label, {bool isNum = false}) {
      final ctrl = TextEditingController(text: config[key]?.toString() ?? '');
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10))),
          Expanded(child: SizedBox(height: 28, child: TextField(
            controller: ctrl,
            onChanged: (v) => config[key] = isNum ? (num.tryParse(v) ?? 0) : v,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              filled: true, fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none)),
          ))),
        ]),
      );
    }

    switch (p) {
      case TagProtocol.mqtt:
        return [f('broker', 'Broker URL'), f('topic', 'Topic'), f('qos', 'QoS', isNum: true), f('username', 'Username'), f('password', 'Password')];
      case TagProtocol.modbusTcp:
        return [f('host', 'Host'), f('port', 'Port', isNum: true), f('unitId', 'Unit ID', isNum: true), f('register', 'Register', isNum: true), f('registerType', 'Reg Type'), f('dataFormat', 'Data Format'), f('byteOrder', 'Byte Order')];
      case TagProtocol.modbusRtu:
        return [f('serialPort', 'Serial Port'), f('baudRate', 'Baud Rate', isNum: true), f('parity', 'Parity'), f('stopBits', 'Stop Bits', isNum: true), f('unitId', 'Unit ID', isNum: true), f('register', 'Register', isNum: true)];
      case TagProtocol.opcua:
        return [f('endpointUrl', 'Endpoint URL'), f('nodeId', 'Node ID'), f('namespaceIndex', 'Namespace', isNum: true), f('securityMode', 'Security Mode'), f('securityPolicy', 'Security Policy'), f('username', 'Username'), f('password', 'Password')];
      case TagProtocol.simulation:
        return [f('pattern', 'Pattern'), f('min', 'Min', isNum: true), f('max', 'Max', isNum: true), f('period', 'Period (ms)', isNum: true), f('noise', 'Noise %', isNum: true)];
    }
  }

  void _showAddGroupDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('New Group', style: TextStyle(color: Colors.white, fontSize: 14)),
      content: SizedBox(height: 32, child: TextField(controller: ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: const InputDecoration(hintText: 'Group name', hintStyle: TextStyle(color: Color(0xFF64748B))))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); /* Group is created when tag uses it */ }, child: const Text('OK')),
      ],
    ));
  }

  Future<void> _deleteTag(Tag tag) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Delete Tag?', style: TextStyle(color: Colors.white)),
      content: Text('Delete "${tag.name}"?', style: const TextStyle(color: Color(0xFF94A3B8))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.del('/tags/${tag.id}');
        _loadData();
      } catch (_) {}
    }
  }

  Future<void> _bulkAction(String action) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/tags/bulk', {'action': action, 'ids': _selectedIds.toList()});
      setState(() { _selectedIds.clear(); _selectMode = false; });
      _loadData();
    } catch (_) {}
  }

  Future<void> _exportCsv() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.get('/tags/export/csv');
    } catch (_) {}
  }
}
