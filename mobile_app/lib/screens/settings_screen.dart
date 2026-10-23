import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification switches
  bool _pushNotifications = true;
  bool _intruderSmsAlerts = true;
  bool _doorAjarAlerts = true;

  // Registered GSM phone numbers for SIM800L SMS alerts
  final List<String> _gsmPhoneNumbers = [
    '+91 81970 37510',
    '+91 75258 26839',
  ];

  void _showAddPhoneDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Register GSM Alert Number',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The SIM800L GSM modem will send automated SMS alerts to this number upon security events.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = phoneController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _gsmPhoneNumbers.add(text);
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Registered $text for SIM800L SMS alerts'),
                    backgroundColor: AppColors.surfaceLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('Add Number'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Confirm Sign Out',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of the Smart Door Lock System?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (FirebaseInitService.isConfigured) {
                  await AuthService.instance.signOut();
                }
              } catch (_) {}
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alarm,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Account Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight, width: 1.5),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Master Administrator',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AuthService.instance.currentUser?.email ?? 'rushi.rajmeher2025@vitstudent.ac.in',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.unlocked.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(color: AppColors.unlocked, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Parameters
          _buildSectionHeader('Hardware Security Parameters'),
          _buildInfoTile(
            icon: Icons.pin_outlined,
            title: 'Master Keypad PIN',
            subtitle: 'Default: "1234" (4-8 digits saved in NVS)',
            trailingText: 'Configured',
          ),
          _buildInfoTile(
            icon: Icons.timer_outlined,
            title: 'Auto-Lock Delay',
            subtitle: 'Locks deadbolt 5s after door closes',
            trailingText: '${AppConstants.autoLockDelaySeconds}s',
          ),
          _buildInfoTile(
            icon: Icons.lock_clock_outlined,
            title: 'Brute-Force Lockout',
            subtitle: 'Lockout after ${AppConstants.maxPinAttempts} wrong PIN entries',
            trailingText: '${AppConstants.lockoutTimeSeconds}s',
          ),
          const SizedBox(height: 20),

          // Notification Preferences
          _buildSectionHeader('Notification Preferences'),
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            subtitle: 'Instant alerts on lock/unlock events',
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          _buildSwitchTile(
            icon: Icons.crisis_alert_rounded,
            title: 'Intruder Siren Alerts',
            subtitle: 'Trigger alarm siren when door forced open',
            value: _intruderSmsAlerts,
            onChanged: (val) => setState(() => _intruderSmsAlerts = val),
          ),
          _buildSwitchTile(
            icon: Icons.door_front_door_outlined,
            title: 'Door Left Open Reminder',
            subtitle: 'Audible beeps after 10s door ajar',
            value: _doorAjarAlerts,
            onChanged: (val) => setState(() => _doorAjarAlerts = val),
          ),
          const SizedBox(height: 20),

          // GSM SMS Alert Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('GSM SMS Alert Recipients'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight, size: 20),
                tooltip: 'Add Alert Phone Number',
                onPressed: _showAddPhoneDialog,
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _gsmPhoneNumbers.asMap().entries.map((entry) {
                final idx = entry.key;
                final phone = entry.value;
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.sim_card_outlined, color: AppColors.accent, size: 22),
                    title: Text(phone, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(idx == 0 ? 'Primary Alert Contact' : 'Secondary Contact',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.alarm, size: 20),
                      onPressed: () {
                        setState(() {
                          _gsmPhoneNumbers.removeAt(idx);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // System & Hardware Information
          _buildSectionHeader('System & Hardware Telemetry'),
          _buildInfoTile(
            icon: Icons.memory_rounded,
            title: 'Controller',
            subtitle: 'ESP32 DevKit V4 (Xtensa LX6 @ 240MHz)',
            trailingText: '3.3V Logic',
          ),
          _buildInfoTile(
            icon: Icons.developer_board_rounded,
            title: 'Actuator',
            subtitle: 'SG90 Micro Servo (PWM GPIO 18)',
            trailingText: '0° / 90°',
          ),
          _buildInfoTile(
            icon: Icons.sim_card_rounded,
            title: 'Cellular Modem',
            subtitle: 'SIM800L GSM (SMS Alert Module)',
            trailingText: 'UART TTL',
          ),
          _buildInfoTile(
            icon: Icons.verified_user_outlined,
            title: 'Firmware Version',
            subtitle: 'ESA Smart Door Lock v2.9',
            trailingText: 'Active',
          ),
          const SizedBox(height: 32),

          // Logout Button
          ElevatedButton.icon(
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sign Out of System'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.alarm,
              side: const BorderSide(color: AppColors.alarm, width: 1.2),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 18),
          ),
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: Text(
            trailingText,
            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 18),
          ),
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primaryLight,
        ),
      ),
    );
  }
}
