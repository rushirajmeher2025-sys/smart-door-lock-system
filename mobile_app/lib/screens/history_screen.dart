import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample placeholder access logs representing events from ESP32 / Firebase
    final sampleLogs = [
      {
        'event': 'Keypad Unlock',
        'time': 'Just now',
        'method': 'PIN (1234)',
        'icon': Icons.dialpad_rounded,
        'color': AppColors.unlocked,
      },
      {
        'event': 'Auto-Lock Engaged',
        'time': '5 mins ago',
        'method': 'Auto-timer (5s)',
        'icon': Icons.lock_clock_rounded,
        'color': AppColors.locked,
      },
      {
        'event': 'Inside Exit Override',
        'time': '12 mins ago',
        'method': 'Pushbutton GPIO 16',
        'icon': Icons.touch_app_rounded,
        'color': AppColors.primaryLight,
      },
      {
        'event': 'Keypad Lock',
        'time': '1 hour ago',
        'method': 'Key A',
        'icon': Icons.lock_outline_rounded,
        'color': AppColors.locked,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: sampleLogs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final log = sampleLogs[index];
          final color = log['color'] as Color;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(log['icon'] as IconData, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['event'] as String,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log['method'] as String,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  log['time'] as String,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
