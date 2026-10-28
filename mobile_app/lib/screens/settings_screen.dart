import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/access_request.dart';
import '../models/lock_state.dart';
import '../repositories/lock_repository.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/firebase_init.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/settings_group.dart';
import 'lock_selection_screen.dart';

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
  StreamSubscription<String?>? _pinSub;
  List<AccessRequest> _pendingRequests = [];
  String? _currentPin;
  bool _pinRevealed = false;
  Timer? _pinHideTimer;

  @override
  void initState() {
    super.initState();
    _pendingRequests = _repository.currentPendingRequests;
    _currentPin = _repository.currentPin;
    _stateSub = _repository.stateStream.listen((s) {
      if (mounted) setState(() => _lockState = s);
    });
    _requestsSub = _repository.pendingRequestsStream.listen((reqs) {
      if (mounted) setState(() => _pendingRequests = reqs);
    });
    _pinSub = _repository.pinStream.listen((pin) {
      if (mounted) setState(() => _currentPin = pin);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _requestsSub?.cancel();
    _pinSub?.cancel();
    _pinHideTimer?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  Future<void> _togglePinVisibility() async {
    if (_pinRevealed) {
      _pinHideTimer?.cancel();
      setState(() => _pinRevealed = false);
      return;
    }
    final ok = await BiometricService.instance.authenticateWithFallback(
      context: context,
      reason: 'Authenticate using fingerprint, face scan, or password to view the keypad PIN',
    );
    if (ok && mounted) {
      setState(() => _pinRevealed = true);
      _pinHideTimer?.cancel();
      _pinHideTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _pinRevealed = false);
      });
    }
  }

  Future<void> _showChangePinDialog() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool oldVerifiedBiometrically = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dialpad_rounded, color: AppColors.brand, size: 24),
              SizedBox(width: 10),
              Text('Change Keypad PIN'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change the door PIN directly from the app. It will synchronize with the physical lock.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (!oldVerifiedBiometrically) ...[
                  TextField(
                    controller: oldPinController,
                    obscureText: obscureOld,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    decoration: InputDecoration(
                      labelText: 'Current PIN',
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.fingerprint_rounded, size: 20),
                            tooltip: 'Verify with biometrics',
                            onPressed: () async {
                              final ok = await BiometricService.instance.authenticateWithFallback(
                                context: context,
                                reason: 'Authenticate to verify old PIN',
                              );
                              if (ok) {
                                setDlgState(() {
                                  oldVerifiedBiometrically = true;
                                  errorText = null;
                                });
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setDlgState(() => obscureOld = !obscureOld),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Current identity verified via biometrics',
                              style: TextStyle(fontSize: 12.5, color: AppColors.brand, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: newPinController,
                  obscureText: obscureNew,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  decoration: InputDecoration(
                    labelText: 'New PIN (4–8 digits)',
                    prefixIcon: const Icon(Icons.pin_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setDlgState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinController,
                  obscureText: obscureConfirm,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN',
                    prefixIcon: const Icon(Icons.check_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setDlgState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: const TextStyle(color: AppColors.alarm, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final oldPin = oldPinController.text.trim();
                final newPin = newPinController.text.trim();
                final confirmPin = confirmPinController.text.trim();

                if (!oldVerifiedBiometrically) {
                  if (oldPin.isEmpty) {
                    setDlgState(() => errorText = 'Enter current PIN or verify with fingerprint');
                    return;
                  }
                  if (_currentPin != null && _currentPin!.isNotEmpty && oldPin != _currentPin) {
                    setDlgState(() => errorText = 'Wrong current PIN (PIN unchanged)');
                    return;
                  }
                }

                if (newPin.length < 4 || newPin.length > 8) {
                  setDlgState(() => errorText = 'New PIN must be 4 to 8 digits');
                  return;
                }

                if (newPin != confirmPin) {
                  setDlgState(() => errorText = 'PINs do not match');
                  return;
                }

                try {
                  await _repository.updatePin(newPin);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _toast('PIN updated successfully');
                  setState(() {
                    _currentPin = newPin;
                    _pinRevealed = true;
                  });
                } catch (e) {
                  setDlgState(() => errorText = 'Failed to update PIN: $e');
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
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
                        ListTile(
                          leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.brand),
                          title: const Text('Switch lock'),
                          subtitle: Text('Current: ${_repository.activeDeviceName} (${_repository.activeDeviceId})'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LockSelectionScreen()),
                            );
                          },
                        ),
                        _InfoRow(icon: Icons.memory_rounded, title: _repository.activeDeviceName, subtitle: 'ESP32 DevKit V4', value: _repository.activeDeviceId, mono: true),
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
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.person_remove_rounded, color: AppColors.alarm, size: 22),
                                          SizedBox(width: 10),
                                          Text('Revoke Access?'),
                                        ],
                                      ),
                                      content: Text(
                                        'Remove access for user "$uid"?\n\nThey will immediately be disconnected from this lock and returned to the lock list.',
                                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: AppColors.alarm),
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: const Text('Revoke Access'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await _repository.setMember(uid, false);
                                    _toast('Access revoked for user. Disconnected immediately.');
                                  }
                                },
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
                    child: SettingsGroup(
                      title: 'Keypad & PIN security',
                      footer: 'Protected by fingerprint, face scan, or password. Keep your PIN confidential.',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dialpad_rounded, color: AppColors.brand),
                          title: const Text('Keypad PIN'),
                          subtitle: Text(
                            _pinRevealed
                                ? (_currentPin ?? '1234')
                                : '••••  (tap eye icon to authenticate & view)',
                            style: _pinRevealed
                                ? AppTheme.mono(fontSize: 16, color: AppColors.textPrimary)
                                : const TextStyle(color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _pinRevealed ? 'Hide PIN' : 'View PIN (requires authentication)',
                                icon: Icon(
                                  _pinRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: _pinRevealed ? AppColors.brand : AppColors.textSecondary,
                                ),
                                onPressed: _togglePinVisibility,
                              ),
                              if (_pinRevealed)
                                IconButton(
                                  tooltip: 'Copy PIN',
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  onPressed: () => _copy(_currentPin ?? '1234', 'PIN'),
                                ),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: _showChangePinDialog,
                                child: const Text('Change', style: TextStyle(fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    delay: const Duration(milliseconds: 160),
                    child: const SettingsGroup(
                      title: 'Lock behavior',
                      footer: 'Configured in lock firmware (config.h).',
                      children: [
                        _InfoRow(icon: Icons.timer_outlined, title: 'Auto-lock', subtitle: 'After the door closes', value: '${AppConstants.autoLockDelaySeconds} s', mono: true),
                        _InfoRow(icon: Icons.lock_clock_outlined, title: 'PIN lockout', subtitle: 'After ${AppConstants.maxPinAttempts} wrong entries', value: '${AppConstants.lockoutTimeSeconds} s', mono: true),
                        _InfoRow(icon: Icons.sensor_door_outlined, title: 'Door left open', subtitle: 'Gentle beeps', value: '${AppConstants.doorWarningSeconds} s', mono: true),
                        _InfoRow(icon: Icons.crisis_alert_rounded, title: 'Break-in alarm', subtitle: 'Only the keypad PIN stops it', value: '30 s', mono: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    delay: const Duration(milliseconds: 170),
                    child: SettingsGroup(
                      title: 'Activity notifications',
                      footer: 'Get real-time push and in-app notifications whenever lock activity occurs.',
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: NotificationService.instance.activityNotificationsEnabled,
                          builder: (context, enabled, _) => SwitchListTile(
                            secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.brand),
                            title: const Text('Activity alerts'),
                            subtitle: const Text('Notifications when the door is locked or unlocked'),
                            value: enabled,
                            onChanged: (val) {
                              NotificationService.instance.activityNotificationsEnabled.value = val;
                              setState(() {});
                            },
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: NotificationService.instance.alarmNotificationsEnabled,
                          builder: (context, enabled, _) => SwitchListTile(
                            secondary: const Icon(Icons.crisis_alert_rounded, color: AppColors.alarm),
                            title: const Text('Security alarms & warnings'),
                            subtitle: const Text('High-priority alerts for break-ins, tampering, & lockouts'),
                            value: enabled,
                            onChanged: (val) {
                              NotificationService.instance.alarmNotificationsEnabled.value = val;
                              setState(() {});
                            },
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: NotificationService.instance.inAppBannersEnabled,
                          builder: (context, enabled, _) => SwitchListTile(
                            secondary: const Icon(Icons.notification_important_outlined),
                            title: const Text('In-app alert banners'),
                            subtitle: const Text('Show floating banner while using the app'),
                            value: enabled,
                            onChanged: (val) {
                              NotificationService.instance.inAppBannersEnabled.value = val;
                              setState(() {});
                            },
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.send_rounded, color: AppColors.brand),
                          title: const Text('Test notification'),
                          subtitle: const Text('Send a test lock activity alert now'),
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () async {
                              await NotificationService.instance.sendTestNotification(
                                lockName: _repository.activeDeviceName,
                              );
                              _toast('Test notification sent!');
                            },
                            child: const Text('Send test', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
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
