import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/lock_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local state placeholder for Phase 1
  DoorLockState _lockState = DoorLockState.initial();

  void _simulateToggle() {
    setState(() {
      _lockState = _lockState.copyWith(
        isLocked: !_lockState.isLocked,
        lastMethod: 'mobile_app_test',
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _lockState.isLocked;
    final statusColor = isLocked ? AppColors.locked : AppColors.unlocked;
    final statusText = isLocked ? 'LOCKED' : 'UNLOCKED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withValues(alpha: 0.15),
                      border: Border.all(color: statusColor, width: 2.5),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 54,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lockState.doorClosed ? 'Door is fully closed' : 'Door is OPEN',
                    style: TextStyle(
                      color: _lockState.doorClosed ? AppColors.textSecondary : AppColors.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Toggle Action Button (Phase 1 UI test)
            ElevatedButton.icon(
              onPressed: _simulateToggle,
              icon: Icon(isLocked ? Icons.key_rounded : Icons.lock_outline_rounded),
              label: Text(isLocked ? 'Unlock Door (Test UI)' : 'Lock Door (Test UI)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? AppColors.primary : AppColors.surfaceLight,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 28),

            // Hardware Telemetry Summary
            const Text(
              'Hardware Telemetry',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTelemetryCard(
                    title: 'Door Sensor',
                    value: _lockState.doorClosed ? 'Closed' : 'Ajar',
                    icon: Icons.door_front_door_outlined,
                    color: _lockState.doorClosed ? AppColors.unlocked : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTelemetryCard(
                    title: 'Burglar Alarm',
                    value: _lockState.burglarAlarmActive ? 'ACTIVE' : 'Disarmed',
                    icon: Icons.security_rounded,
                    color: _lockState.burglarAlarmActive ? AppColors.alarm : AppColors.unlocked,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryCard(
                    title: 'ESP32 Status',
                    value: 'Ready (Offline)',
                    icon: Icons.memory_rounded,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTelemetryCard(
                    title: 'GSM Modem',
                    value: 'SIM800L Ready',
                    icon: Icons.sim_card_outlined,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
