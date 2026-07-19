// ignore_for_file: deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
// ignore: unused_import
import '../services/api_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _totalPages = 0;
  int _totalTags = 0;
  int _activeTags = 0;
  int _totalAlarms = 0;
  int _unackAlarms = 0;
  int _totalUsers = 0;
  Map<String, int> _tagsByProtocol = {};
  Map<String, int> _tagsByGroup = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final pagesRes = await api.get('/pages');
      final tagsRes = await api.get('/tags');
      final groupsRes = await api.get('/tags/groups');

      final pages = pagesRes['pages'] as List? ?? [];
      final tags = tagsRes['tags'] as List? ?? [];
      final groups = groupsRes['groups'] as List? ?? [];

      final byProto = <String, int>{};
      for (final t in tags) {
        final p = t['protocol'] ?? 'unknown';
        byProto[p] = (byProto[p] ?? 0) + 1;
      }

      final byGroup = <String, int>{};
      for (final g in groups) {
        byGroup[g['name'] ?? 'Default'] = g['count'] ?? 0;
      }

      setState(() {
        _totalPages = pages.length;
        _totalTags = tags.length;
        _activeTags = tags.where((t) => t['isActive'] == true).length;
        _tagsByProtocol = byProto;
        _tagsByGroup = byGroup;
        _loading = false;
      });

      // Try alarms
      try {
        final alarmsRes = await api.get('/alarms');
        final alarms = alarmsRes['alarms'] as List? ?? [];
        setState(() {
          _totalAlarms = alarms.length;
          _unackAlarms = alarms.where((a) => a['acknowledged'] != true).length;
        });
      } catch (_) {}

      // Try users
      try {
        final usersRes = await api.get('/admin/users');
        setState(() => _totalUsers = (usersRes['users'] as List?)?.length ?? 0);
      } catch (_) {}
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('System Overview', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.withValues(alpha: 0.2)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Summary cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard('📄', 'Pages', _totalPages.toString(), Colors.blue),
              _statCard('🏷️', 'Tags', '$_activeTags / $_totalTags', Colors.green),
              _statCard('🔔', 'Alarms', '$_unackAlarms unack', _unackAlarms > 0 ? Colors.red : Colors.green),
              _statCard('👥', 'Users', _totalUsers.toString(), Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Tags by Protocol
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionCard('📡 Tags by Protocol', _tagsByProtocol.entries.map((e) =>
                  _barItem(e.key, e.value, _totalTags, _protoColor(e.key))).toList()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _sectionCard('📁 Tags by Group', _tagsByGroup.entries.map((e) =>
                  _barItem(e.key, e.value, _totalTags, Colors.blue)).toList()),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Connection Status
          _sectionCard('🔌 Connection Status', [
            _statusRow('MQTT', _tagsByProtocol['mqtt'] ?? 0, Colors.green),
            _statusRow('Modbus TCP', _tagsByProtocol['modbusTcp'] ?? 0, Colors.blue),
            _statusRow('Modbus RTU', _tagsByProtocol['modbusRtu'] ?? 0, Colors.indigo),
            _statusRow('OPC UA', _tagsByProtocol['opcua'] ?? 0, Colors.purple),
            _statusRow('Simulation', _tagsByProtocol['simulation'] ?? 0, Colors.amber),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String icon, String label, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _barItem(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
              Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String protocol, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            shape: BoxShape.circle, color: count > 0 ? color : Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(protocol, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text('$count tags', style: TextStyle(color: count > 0 ? color : Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Color _protoColor(String p) {
    switch (p) {
      case 'mqtt': return Colors.green;
      case 'modbusTcp': return Colors.blue;
      case 'modbusRtu': return Colors.indigo;
      case 'opcua': return Colors.purple;
      case 'simulation': return Colors.amber;
      default: return Colors.grey;
    }
  }
}

