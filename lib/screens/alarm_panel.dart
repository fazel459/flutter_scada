// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/enums.dart';

class AlarmPanel extends ConsumerWidget {
  const AlarmPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmState = ref.watch(alarmProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      constraints: const BoxConstraints(maxHeight: 256),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Alarms & Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${alarmState.unacknowledged}',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await ref.read(alarmProvider.notifier).loadAlarms();
                  },
                  child: const Text('Refresh', style: TextStyle(fontSize: 11)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                  onPressed: () {
                    ref.read(panelsVisibleProvider.notifier).update((state) => {
                      ...state,
                      'alarmPanel': false,
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: alarmState.alarms.isEmpty
                ? const Center(
                    child: Text('No alarms', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : ListView.separated(
                    itemCount: alarmState.alarms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                    itemBuilder: (ctx, i) {
                      final alarm = alarmState.alarms[i];
                      return Container(
                        color: alarm.acknowledged ? null : Colors.red.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: alarm.acknowledged ? Colors.grey : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(alarm.widgetLabel ?? alarm.widgetId,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _alarmColor(alarm.alarmType),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(alarm.alarmType.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 9)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Value: ${alarm.value?.toStringAsFixed(1) ?? '-'} | Threshold: ${alarm.threshold?.toStringAsFixed(1) ?? '-'}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(_timeString(alarm.createdAt),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                            const SizedBox(width: 8),
                            if (!alarm.acknowledged)
                              TextButton(
                                onPressed: () => ref.read(alarmProvider.notifier).acknowledgeAlarm(alarm.id ?? -1),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                child: const Text('ACK', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _alarmColor(String type) {
    if (type.contains('high')) return Colors.red;
    if (type.contains('low')) return Colors.orange;
    return Colors.amber;
  }

  String _timeString(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

