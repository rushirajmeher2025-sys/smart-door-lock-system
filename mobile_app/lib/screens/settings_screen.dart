import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/screen_header.dart';
import '../widgets/settings_group.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _intruderSmsAlerts = true;
  bool _doorAjarAlerts = true;

  final List<String> _gsmPhoneNumbers = [
    '+91 81970 37510',
    '+91 75258 26839',
  ];

  void _showAddPhoneDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add alert number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The lock sends an SMS to this number when something happens.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setState(() => _gsmPhoneNumbers.add(text));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$text will get SMS alerts')),
              );
            },
            child: const Text('Add number'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You’ll need to sign in again to control the lock.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alarm),
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
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? 'rushi.rajmeher2025@vitstudent.ac.in';
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const ScreenHeader(title: 'Settings'),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Master Administrator',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: 'Lock behavior',
              children: [
                const _InfoRow(
                  icon: Icons.pin_outlined,
                  title: 'Keypad PIN',
                  subtitle: 'Stored on the lock, 4 to 8 digits',
                  value: 'Set',
                ),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  title: 'Auto-lock',
                  subtitle: 'Locks after the door closes',
                  value: '${AppConstants.autoLockDelaySeconds} s',
                ),
                _InfoRow(
                  icon: Icons.lock_clock_outlined,
                  title: 'PIN lockout',
                  subtitle: 'After ${AppConstants.maxPinAttempts} wrong entries',
                  value: '${AppConstants.lockoutTimeSeconds} s',
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: 'Alerts',
              children: [
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push notifications',
                  subtitle: 'Every lock and unlock',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                _SwitchRow(
                  icon: Icons.crisis_alert_rounded,
                  title: 'Break-in siren',
                  subtitle: 'Sounds when the door is forced open',
                  value: _intruderSmsAlerts,
                  onChanged: (v) => setState(() => _intruderSmsAlerts = v),
                ),
                _SwitchRow(
                  icon: Icons.door_front_door_outlined,
                  title: 'Door left open',
                  subtitle: 'Beeps after ${AppConstants.doorWarningSeconds} s',
                  value: _doorAjarAlerts,
                  onChanged: (v) => setState(() => _doorAjarAlerts = v),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: 'SMS recipients',
              children: [
                for (var i = 0; i < _gsmPhoneNumbers.length; i++)
                  ListTile(
                    leading: const Icon(Icons.sms_outlined),
                    title: Text(_gsmPhoneNumbers[i]),
                    subtitle: Text(i == 0 ? 'Primary contact' : 'Backup contact'),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() => _gsmPhoneNumbers.removeAt(i)),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: AppColors.primaryLight),
                  title: const Text(
                    'Add a number',
                    style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                  ),
                  onTap: _showAddPhoneDialog,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const SettingsGroup(
              title: 'Hardware',
              children: [
                _InfoRow(
                  icon: Icons.memory_rounded,
                  title: 'Controller',
                  subtitle: 'ESP32 DevKit V4',
                  value: '240 MHz',
                ),
                _InfoRow(
                  icon: Icons.settings_input_component_outlined,
                  title: 'Deadbolt actuator',
                  subtitle: 'SG90 servo on GPIO 18',
                  value: '0° / 90°',
                ),
                _InfoRow(
                  icon: Icons.sim_card_outlined,
                  title: 'Cellular modem',
                  subtitle: 'SIM800L for SMS alerts',
                  value: 'UART',
                ),
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Firmware',
                  subtitle: 'ESA Smart Door Lock',
                  value: 'v2.9',
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.alarm),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.alarm, fontWeight: FontWeight.w600),
                  ),
                  onTap: _showLogoutConfirmation,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppConstants.appName} ${AppConstants.appVersion}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}
