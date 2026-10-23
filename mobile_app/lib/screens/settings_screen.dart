import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Security & Credentials'),
          _buildSettingTile(
            icon: Icons.pin_outlined,
            title: 'Change Lock PIN',
            subtitle: 'Update master 4-8 digit keypad PIN',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.timer_outlined,
            title: 'Auto-Lock Delay',
            subtitle: '${AppConstants.autoLockDelaySeconds}s after door closure',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.lock_clock_outlined,
            title: 'Brute-Force Lockout',
            subtitle: '${AppConstants.lockoutTimeSeconds}s after ${AppConstants.maxPinAttempts} failed attempts',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Alerts & Notifications'),
          _buildSettingTile(
            icon: Icons.sms_outlined,
            title: 'GSM SMS Alerts (SIM800L)',
            subtitle: 'Configured phone numbers for SMS',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'Burglar Siren Duration',
            subtitle: '30 seconds emergency siren',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Device & System'),
          _buildSettingTile(
            icon: Icons.memory_rounded,
            title: 'Hardware Controller',
            subtitle: 'ESP32 DevKit V4 (Xtensa LX6)',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            title: 'Firmware Version',
            subtitle: 'ESA Smart Door Lock v2.9',
            onTap: () {},
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
            },
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.alarm,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
