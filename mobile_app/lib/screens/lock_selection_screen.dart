import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_device_info.dart';
import '../repositories/lock_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import 'main_nav_screen.dart';

class LockSelectionScreen extends StatefulWidget {
  const LockSelectionScreen({super.key});

  @override
  State<LockSelectionScreen> createState() => _LockSelectionScreenState();
}

class _LockSelectionScreenState extends State<LockSelectionScreen> {
  final LockRepository _repository = lockRepository();
  StreamSubscription<List<LockDeviceInfo>>? _locksSub;
  List<LockDeviceInfo> _locks = [];
  bool _loading = false;
  bool _navigating = false;
  String? _pendingApprovalDeviceId;
  VoidCallback? _accessListener;

  @override
  void initState() {
    super.initState();
    _locks = _repository.availableLocks;
    _locksSub = _repository.availableLocksStream.listen((list) {
      if (!mounted) return;
      final user = AuthService.instance.currentUser;
      for (final newLock in list) {
        final isApprovedNow = newLock.isMember(user?.uid);
        final wasPending = _pendingApprovalDeviceId == newLock.deviceId ||
            _locks.any((l) => l.deviceId == newLock.deviceId && l.isPending(user?.uid));
        if (isApprovedNow && wasPending) {
          _pendingApprovalDeviceId = null;
          _toast('Access to "${newLock.deviceName}" approved by owner! Opening lock...');
          _openLock(newLock);
          return;
        }
      }
      setState(() => _locks = list);
    });

    _accessListener = () {
      if (!mounted) return;
      final access = _repository.access.value;
      final user = AuthService.instance.currentUser;
      final isMember = access.status == AccessStatus.member || (user?.uid != null && access.members[user!.uid] == true);
      if (isMember) {
        final lock = _locks.firstWhere(
          (l) => l.deviceId == _repository.activeDeviceId,
          orElse: () => _locks.isNotEmpty
              ? _locks.first
              : LockDeviceInfo(
                  deviceId: _repository.activeDeviceId,
                  deviceName: _repository.activeDeviceName,
                ),
        );
        _toast('Access approved by owner! Opening "${lock.deviceName}"...');
        _openLock(lock);
      } else {
        setState(() {});
      }
    };
    _repository.access.addListener(_accessListener!);
  }

  @override
  void dispose() {
    _locksSub?.cancel();
    if (_accessListener != null) {
      _repository.access.removeListener(_accessListener!);
    }
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLock(LockDeviceInfo lock) async {
    if (_navigating || !mounted) return;
    _navigating = true;
    setState(() => _loading = true);
    await _repository.setActiveDevice(lock.deviceId, deviceName: lock.deviceName);
    if (mounted) {
      // Dismiss any open modals or dialogs first
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
    }
  }

  Future<void> _selectLock(LockDeviceInfo lock) async {
    final user = AuthService.instance.currentUser;
    final access = _repository.access.value;
    final isOwner = lock.isOwner(user?.uid) || (user?.uid != null && lock.ownerUid == user?.uid) || access.isOwner;
    final isMember = lock.isMember(user?.uid) ||
        (user?.uid != null && (lock.authorizedUsers[user!.uid] == true || access.members[user.uid] == true || access.status == AccessStatus.member));

    if (isOwner || isMember) {
      await _openLock(lock);
    } else if (lock.isPending(user?.uid) || (access.deviceUid == lock.deviceId && access.isPendingApproval)) {
      _showWaitingForApprovalDialog(lock);
    } else {
      _showRequestAccessDialog(lock);
    }
  }

  void _showWaitingForApprovalDialog(LockDeviceInfo lock) {
    final user = AuthService.instance.currentUser;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.brand),
            ),
            SizedBox(width: 12),
            Text('Waiting for Approval'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request to access "${lock.deviceName}" is awaiting approval from the lock owner.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'As soon as the owner approves your request, this screen will automatically open and take you directly to the lock.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (_repository.isSimulation)
            TextButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Approve as Owner (Demo)'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _repository.approveRequest(user?.uid ?? 'demo-user');
                _toast('Owner approved request! Opening lock...');
                final updatedLock = _repository.availableLocks.firstWhere(
                  (l) => l.deviceId == lock.deviceId,
                  orElse: () => lock,
                );
                await _openLock(updatedLock);
              },
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  Future<void> _showRequestAccessDialog(LockDeviceInfo lock) async {
    final email = AuthService.instance.currentUser?.email ?? 'your email';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.brand, size: 22),
            SizedBox(width: 10),
            Text('Request Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to request access to "${lock.deviceName}"?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'A request with your account ($email) will be sent to the lock owner for approval.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      _pendingApprovalDeviceId = lock.deviceId;
      await _repository.setActiveDevice(lock.deviceId, deviceName: lock.deviceName);
      await _repository.requestAccess(email: email);
      if (mounted) {
        setState(() {
          _loading = false;
          _locks = _repository.availableLocks;
        });
        _showWaitingForApprovalDialog(lock);
      }
    }
  }

  Future<void> _showAddLockDialog() async {
    final controller = TextEditingController();
    final nameController = TextEditingController(text: 'Smart Door Lock');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.brand, size: 22),
            SizedBox(width: 10),
            Text('Connect to Lock'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g. esp32_lock_01',
                prefixIcon: Icon(Icons.qr_code_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Lock Label',
                hintText: 'e.g. Garage Door, Front Door',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.of(ctx).pop();
              final name = nameController.text.trim().isEmpty ? 'Smart Door Lock' : nameController.text.trim();
              await _repository.setActiveDevice(id, deviceName: name);
              _toast('Switched to lock $id');
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out of LocKify?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alarm),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.instance.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final userEmail = currentUser?.email ?? 'Demo User';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        tint: AppColors.brand,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  children: [
                    const BrandMark(size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppConstants.appName, style: AppTheme.display(fontSize: 18)),
                        Text(userEmail, style: AppTheme.mono(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
                      tooltip: 'Sign out',
                      onPressed: _showSignOutDialog,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.hairline),

              // Title section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECT A LOCK', style: AppTheme.label()),
                    const SizedBox(height: 4),
                    Text('Available Locks', style: AppTheme.display(fontSize: 24)),
                    const SizedBox(height: 6),
                    const Text(
                      'Select an authorized lock to open controls, or request access from the lock owner.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              // Locks list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [
                          if (_locks.isEmpty) ...[
                            _buildLockCard(
                              LockDeviceInfo(
                                deviceId: AppConstants.deviceId,
                                deviceName: AppConstants.deviceName,
                                hardware: 'ESP32 DevKit V4',
                                isOnline: true,
                              ),
                              currentUser?.uid,
                            ),
                          ] else ...[
                            for (final lock in _locks) _buildLockCard(lock, currentUser?.uid),
                          ],
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: AppColors.hairline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Connect to Another Lock by ID'),
                            onPressed: _showAddLockDialog,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockCard(LockDeviceInfo lock, String? currentUid) {
    final access = _repository.access.value;
    final isOwner = lock.isOwner(currentUid) || (currentUid != null && lock.ownerUid == currentUid) || access.isOwner;
    final isMember = lock.isMember(currentUid) ||
        (currentUid != null && (lock.authorizedUsers[currentUid] == true || access.members[currentUid] == true || access.status == AccessStatus.member));
    final isPending = !isMember && !isOwner && (lock.isPending(currentUid) || access.isPendingApproval);

    final Color badgeColor;
    final String badgeLabel;
    final IconData badgeIcon;

    if (isOwner) {
      badgeColor = AppColors.brand;
      badgeLabel = 'OWNER';
      badgeIcon = Icons.stars_rounded;
    } else if (isMember) {
      badgeColor = const Color(0xFF38BDF8); // Sky blue
      badgeLabel = 'MEMBER ACCESS';
      badgeIcon = Icons.verified_user_rounded;
    } else if (isPending) {
      badgeColor = AppColors.warning;
      badgeLabel = 'REQUEST PENDING';
      badgeIcon = Icons.hourglass_top_rounded;
    } else {
      badgeColor = AppColors.textMuted;
      badgeLabel = 'NOT LINKED';
      badgeIcon = Icons.lock_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (lock.isOnline ? AppColors.brand : AppColors.offline).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (lock.isOnline ? AppColors.brand : AppColors.offline).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    lock.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: lock.isOnline ? AppColors.brand : AppColors.offline,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lock.deviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${lock.deviceId} · ${lock.hardware}',
                        style: AppTheme.mono(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (lock.isOnline ? AppColors.brand : AppColors.offline).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lock.isOnline ? AppColors.brand : AppColors.offline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lock.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: AppTheme.mono(
                          fontSize: 10,
                          color: lock.isOnline ? AppColors.brand : AppColors.offline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: AppTheme.mono(fontSize: 11, color: badgeColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isOwner || isMember) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Open Lock'),
                    onPressed: () => _selectLock(lock),
                  ),
                ] else if (isPending) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 15),
                    label: const Text('Pending Approval', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                    onPressed: () => _selectLock(lock),
                  ),
                ] else ...[
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16),
                    label: const Text('Request Access'),
                    onPressed: () => _selectLock(lock),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
