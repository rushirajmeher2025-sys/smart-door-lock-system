import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/access_request.dart';
import '../models/lock_state.dart';
import '../repositories/lock_repository.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/settings_group.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LockRepository _repository = lockRepository();
  late DoorLockState _lockState = _repository.currentState;
  StreamSubscription<DoorLockState>? _stateSub;
  StreamSubscription<List<AccessRequest>>? _requestsSub;
  List<AccessRequest> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _pendingRequests = _repository.currentPendingRequests;
    _stateSub = _repository.stateStream.listen((s) {
      if (mounted) setState(() => _lockState = s);
    });
    _requestsSub = _repository.pendingRequestsStream.listen((reqs) {
      if (mounted) setState(() => _pendingRequests = reqs);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  Future<void> _askForUid({
    required String title,
    required String body,
    required String action,
    required Future<void> Function(String uid) onSubmit,
  }) async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTheme.mono(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'User ID', prefixIcon: Icon(Icons.fingerprint_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: Text(action)),
        ],
      ),
    );
    if (uid == null || uid.isEmpty) return;
    try {
      await onSubmit(uid);
    } catch (e) {
      _toast('Couldn’t save: $e');
    }
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.alarm, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (FirebaseInitService.isConfigured) {
                  await AuthService.instance.signOut();
                }
              } catch (_) {}
              if (!mounted) return;
              // Back through the auth gate so signing in again lands on the dashboard
              Navigator.of(context).pushNamedAndRemoveUntil(AppConstants.routeGate, (_) => false);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demo = _repository.isSimulation;
    final email = FirebaseInitService.isConfigured ? (AuthService.instance.currentUser?.email ?? '') : 'demo@lockify.app';
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();
    final s = _lockState;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<LockAccess>(
            valueListenable: _repository.access,
            builder: (context, access, _) {
              final role = switch (access.status) {
                AccessStatus.owner => ('OWNER', AppColors.brand),
                AccessStatus.member => ('MEMBER', AppColors.textSecondary),
                AccessStatus.demo => ('DEMO', AppColors.textSecondary),
                AccessStatus.denied => ('NO ACCESS', AppColors.alarm),
                AccessStatus.error => ('ERROR', AppColors.alarm),
                AccessStatus.checking => ('CHECKING', AppColors.textMuted),
              };
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  const ScreenHeader(title: 'Settings', subtitle: AppConstants.appName),
                  const SizedBox(height: 22),
                  Reveal(
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Text(initial, style: AppTheme.display(fontSize: 18, letterSpacing: 0)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
                                    ),
                                    const SizedBox(height: 6),
                                    Pill(label: role.$1, color: role.$2, icon: Icons.verified_user_outlined),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (access.uid != null && !demo) ...[
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text('USER ID', style: AppTheme.label()),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(access.uid!, overflow: TextOverflow.ellipsis, style: AppTheme.mono(fontSize: 12, color: AppColors.textSecondary)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Copy user ID',
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  onPressed: () => _copy(access.uid!, 'User ID'),
                                ),
                              ],
                            ),
                          ],
                          if (access.message != null) ...[
                            const SizedBox(height: 8),
                            Text(access.message!, style: const TextStyle(color: AppColors.alarm, fontSize: 13, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    delay: const Duration(milliseconds: 60),
                    child: SettingsGroup(
                      title: 'Lock hardware',
                      footer: access.isOwner && !access.hardwareLinked
                          ? 'The lock prints its user ID in the Arduino Serial Monitor (115200 baud) when it starts.'
                          : null,
                      children: [
                        _InfoRow(icon: Icons.memory_rounded, title: AppConstants.deviceName, subtitle: 'ESP32 DevKit V4', value: AppConstants.deviceId, mono: true),
                        _InfoRow(
                          icon: s.isConfirmed ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          title: 'Connection',
                          subtitle: s.isConfirmed ? 'Reporting every 10 s' : 'Not reporting right now',
                          value: s.isConfirmed ? 'Online' : 'Offline',
                          valueColor: s.isConfirmed ? AppColors.brand : AppColors.textMuted,
                        ),
                        _InfoRow(
                          icon: Icons.developer_board_rounded,
                          title: 'Firmware',
                          subtitle: 'ESA Smart Door Lock',
                          value: s.firmwareVersion != null ? 'v${s.firmwareVersion}' : '—',
                          mono: true,
                        ),
                        ListTile(
                          leading: const Icon(Icons.link_rounded),
                          title: const Text('Lock account'),
                          subtitle: Text(access.hardwareLinked ? 'Linked, the lock can report and take commands' : 'Not linked yet'),
                          trailing: access.hardwareLinked
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 20)
                              : (access.isOwner ? const Icon(Icons.chevron_right_rounded) : null),
                          onTap: access.isOwner
                              ? () => _askForUid(
                                    title: 'Link the lock',
                                    body: 'Paste the user ID of the lock’s own Firebase account so it can report and receive commands.',
                                    action: 'Link',
                                    onSubmit: (uid) async {
                                      await _repository.linkHardware(uid);
                                      _toast('Lock account linked');
                                    },
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (access.isOwner) ...[
                    if (_pendingRequests.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Reveal(
                        delay: const Duration(milliseconds: 90),
                        child: SettingsGroup(
                          title: 'Pending access requests (${_pendingRequests.length})',
                          footer: 'Approve to grant immediate access to control the lock.',
                          children: [
                            for (final req in _pendingRequests)
                              ListTile(
                                leading: const Icon(Icons.person_add_rounded, color: AppColors.brand),
                                title: Text(req.email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text('UID: ${req.uid} · ${agoShort(req.requestedAt)}', style: AppTheme.mono(fontSize: 11, color: AppColors.textMuted)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 24),
                                      tooltip: 'Approve',
                                      onPressed: () async {
                                        await _repository.approveRequest(req.uid);
                                        _toast('Approved access for ${req.email}');
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel_rounded, color: AppColors.alarm, size: 24),
                                      tooltip: 'Decline',
                                      onPressed: () async {
                                        await _repository.rejectRequest(req.uid);
                                        _toast('Declined request for ${req.email}');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Reveal(
                      delay: const Duration(milliseconds: 100),
                      child: SettingsGroup(
                        title: 'People with access',
                        footer: 'They create an account in LocKify, then request access or send you their user ID.',
                        children: [
                          for (final uid in access.members.keys)
                            ListTile(
                              leading: const Icon(Icons.person_outline_rounded),
                              title: Text(uid, overflow: TextOverflow.ellipsis, style: AppTheme.mono(fontSize: 12.5, color: AppColors.textPrimary)),
                              trailing: IconButton(
                                tooltip: 'Remove access',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => _repository.setMember(uid, false),
                              ),
                            ),
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_rounded, color: AppColors.textPrimary),
                            title: const Text('Add a person'),
                            onTap: () => _askForUid(
                              title: 'Give access',
                              body: 'They’ll be able to see the lock and lock or unlock it.',
                              action: 'Give access',
                              onSubmit: (uid) async {
                                await _repository.setMember(uid, true);
                                _toast('Access granted');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Reveal(
                    delay: const Duration(milliseconds: 140),
                    child: const SettingsGroup(
                      title: 'Lock behavior',
                      footer: 'Set in the firmware (config.h). The keypad PIN never leaves the lock.',
                      children: [
                        _InfoRow(icon: Icons.pin_outlined, title: 'Keypad PIN', subtitle: '${AppConstants.minPinLength} to ${AppConstants.maxPinLength} digits, change with C', value: 'On lock'),
                        _InfoRow(icon: Icons.timer_outlined, title: 'Auto-lock', subtitle: 'After the door closes', value: '${AppConstants.autoLockDelaySeconds} s', mono: true),
                        _InfoRow(icon: Icons.lock_clock_outlined, title: 'PIN lockout', subtitle: 'After ${AppConstants.maxPinAttempts} wrong entries', value: '${AppConstants.lockoutTimeSeconds} s', mono: true),
                        _InfoRow(icon: Icons.sensor_door_outlined, title: 'Door left open', subtitle: 'Gentle beeps', value: '${AppConstants.doorWarningSeconds} s', mono: true),
                        _InfoRow(icon: Icons.crisis_alert_rounded, title: 'Break-in alarm', subtitle: 'Only the keypad PIN stops it', value: '30 s', mono: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Reveal(
                    delay: Duration(milliseconds: 180),
                    child: SettingsGroup(
                      title: 'SMS alerts',
                      children: [
                        ListTile(
                          leading: Icon(Icons.sms_outlined),
                          title: Text('Text messages on break-ins'),
                          subtitle: Text('Arrives with the GSM module'),
                          trailing: Pill(label: 'SOON', color: AppColors.textMuted, icon: Icons.schedule_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SettingsGroup(
                    title: 'Account',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout_rounded, color: AppColors.alarm),
                        title: const Text('Sign out', style: TextStyle(color: AppColors.alarm)),
                        onTap: _showLogoutConfirmation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        const LockifyLogo(size: 28, live: false),
                        const SizedBox(height: 10),
                        Text('${AppConstants.appName.toUpperCase()} ${AppConstants.appVersion}', style: AppTheme.label()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
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
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? AppColors.textSecondary;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: mono
            ? AppTheme.mono(fontSize: 12.5, color: color)
            : TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}
