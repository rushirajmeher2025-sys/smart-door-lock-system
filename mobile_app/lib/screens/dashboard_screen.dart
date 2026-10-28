import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/access_request.dart';
import '../models/lock_state.dart';
import '../models/remote_command.dart';
import '../models/security_event.dart';
import '../repositories/lock_repository.dart';
import '../repositories/mock_lock_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/event_tile.dart';
import '../widgets/lock_orb.dart';
import '../widgets/panel.dart';
import '../widgets/swipe_to_confirm.dart';
import 'lock_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToMembers;

  const DashboardScreen({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToMembers,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LockRepository _repository = lockRepository();
  late DoorLockState _lockState;
  late List<SecurityEvent> _recentEvents;
  StreamSubscription<DoorLockState>? _stateSub;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;
  StreamSubscription<List<AccessRequest>>? _requestsSub;
  List<AccessRequest> _pendingRequests = [];

  CommandOutcome? _outcome;
  Timer? _outcomeTimer;
  int _celebrate = 0;
  bool _submittingRequest = false;

  @override
  void initState() {
    super.initState();
    _lockState = _repository.currentState;
    _recentEvents = _repository.currentEvents.take(4).toList();
    _pendingRequests = _repository.currentPendingRequests;
    _stateSub = _repository.stateStream.listen((state) {
      if (mounted) setState(() => _lockState = state);
    });
    _eventsSub = _repository.eventsStream.listen((events) {
      if (mounted) setState(() => _recentEvents = events.take(4).toList());
    });
    _requestsSub = _repository.pendingRequestsStream.listen((reqs) {
      if (mounted) setState(() => _pendingRequests = reqs);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventsSub?.cancel();
    _requestsSub?.cancel();
    _outcomeTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final email = AuthService.instance.currentUser?.email ?? 'User';
    setState(() => _submittingRequest = true);
    try {
      await _repository.requestAccess(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access request sent to the owner')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  }

  Future<void> _run(bool lock) async {
    setState(() => _outcome = null);
    final outcome = await _repository.sendCommand(lock ? RemoteAction.lock : RemoteAction.unlock);
    if (!mounted) return;
    outcome.ok ? HapticFeedback.heavyImpact() : HapticFeedback.vibrate();
    setState(() {
      _outcome = outcome;
      if (outcome.ok) _celebrate++;
    });
    _outcomeTimer?.cancel();
    _outcomeTimer = Timer(Duration(seconds: outcome.ok ? 4 : 9), () {
      if (mounted) setState(() => _outcome = null);
    });
  }

  void _openSimulation() {
    final mock = MockLockRepository.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<DoorLockState>(
        stream: mock.stateStream,
        initialData: mock.currentState,
        builder: (ctx, snap) {
          final s = snap.data!;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIMULATOR', style: AppTheme.label()),
                  const SizedBox(height: 6),
                  Text('Play the lock’s side', style: AppTheme.display(fontSize: 22, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'Demo mode only. Trigger what the hardware would report.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Door open'),
                    subtitle: const Text('Opening it while locked sets off the alarm'),
                    value: !s.doorClosed,
                    onChanged: (_) => mock.toggleDoorSensor(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lock offline'),
                    subtitle: const Text('Wi-Fi or power lost'),
                    value: !s.isOnline,
                    onChanged: (_) => mock.toggleConnection(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: mock.enterPinOnKeypad,
                    icon: const Icon(Icons.dialpad_rounded, size: 18),
                    label: const Text('Enter the right PIN on the keypad'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _lockState;
    final confirmed = s.isConfirmed;
    final alarm = s.burglarAlarmActive && s.hasReport;

    final Color color;
    final String title;
    if (!s.hasReport || s.syncIssue != null) {
      color = AppColors.offline;
      title = s.syncIssue != null ? 'No access' : 'Waiting';
    } else if (alarm) {
      color = AppColors.alarm;
      title = 'Intruder';
    } else if (!s.isOnline) {
      color = AppColors.offline;
      title = 'Offline';
    } else if (s.isLocked) {
      color = AppColors.secure;
      title = 'Locked';
    } else if (s.isUnlocked) {
      color = AppColors.open;
      title = 'Unlocked';
    } else {
      color = AppColors.offline;
      title = 'Unknown';
    }

    final String subtitle;
    if (s.isActionPending) {
      subtitle = s.pendingActionMessage ?? 'Waiting for the lock…';
    } else if (s.syncIssue != null) {
      subtitle = s.syncIssue!;
    } else if (!s.hasReport) {
      subtitle = 'Power on the lock and connect it to Wi-Fi.';
    } else if (alarm) {
      subtitle = 'Door opened while locked. Enter the PIN on the keypad.';
    } else if (!s.isOnline) {
      final last = s.isLocked ? 'locked' : (s.isUnlocked ? 'unlocked' : 'unknown');
      subtitle = 'Last report: $last, ${agoLong(s.lastUpdated)}';
    } else {
      subtitle = 'Confirmed by the lock · ${agoLong(s.lastUpdated)}';
    }

    final wantsLock = !s.isLocked;
    final blockedByDoor = wantsLock && !s.doorClosed;
    final canAct = confirmed && !s.isActionPending && !blockedByDoor && !alarm;
    final String actionLabel;
    if (!confirmed) {
      actionLabel = 'Lock is offline';
    } else if (s.isActionPending) {
      actionLabel = 'Waiting for the lock…';
    } else if (alarm) {
      actionLabel = 'Use the keypad PIN to stop the alarm';
    } else if (blockedByDoor) {
      actionLabel = 'Close the door to lock';
    } else {
      actionLabel = wantsLock ? 'Slide to lock' : 'Slide to unlock';
    }

    final live = confirmed && !_repository.isSimulation;

    return ValueListenableBuilder<LockAccess>(
      valueListenable: _repository.access,
      builder: (context, access, _) {
        if (access.status == AccessStatus.denied) {
          return _buildRequestAccessView(context, access);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Backdrop(
            tint: color,
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 28),
                      const SizedBox(width: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LockSelectionScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _repository.activeDeviceName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_repository.isSimulation)
                        const Pill(label: 'DEMO', color: AppColors.textSecondary, icon: Icons.science_outlined)
                      else
                        Pill(
                          label: live ? 'LIVE' : 'OFFLINE',
                          color: live ? AppColors.brand : AppColors.offline,
                          pulse: live,
                        ),
                      if (_repository.isSimulation) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Simulator',
                          icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
                          onPressed: _openSimulation,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (access.isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brand.withValues(alpha: 0.16),
                            AppColors.surfaceLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.brand, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OWNER PORTAL',
                                  style: TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Full Administrator & Hardware Control',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onNavigateToMembers != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              onPressed: widget.onNavigateToMembers,
                              icon: const Icon(Icons.group_outlined, size: 15),
                              label: Text(
                                _pendingRequests.isNotEmpty ? '${_pendingRequests.length} pending' : 'Members',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _pendingRequests.isNotEmpty ? AppColors.warning : AppColors.brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            AppColors.surfaceLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MEMBER PORTAL',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Authorized Guest & Family Access',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (access.isOwner && _pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    for (final req in _pendingRequests) _buildPendingRequestCard(req),
                  ],
              const SizedBox(height: 26),
              Reveal(
                child: Text(
                  '${AppConstants.deviceName.toUpperCase()}  ·  ${AppConstants.deviceId.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppTheme.label(),
                ),
              ),
              const SizedBox(height: 6),
              Reveal(
                delay: const Duration(milliseconds: 60),
                child: Center(
                  child: LockOrb(
                    // Unknown state shows the neutral closed silhouette; grey + title say it's unconfirmed
                    locked: s.isLocked || s.isUnknown || !s.hasReport,
                    pending: s.isActionPending,
                    dim: !confirmed && !alarm,
                    alarm: alarm,
                    color: color,
                    celebrate: _celebrate,
                    size: 248,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: AppTheme.display(fontSize: 44, letterSpacing: -2, color: color == AppColors.offline ? AppColors.textPrimary : color),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                // Only the incoming line is laid out, so quick changes never overlap
                layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
                child: Text(
                  subtitle,
                  key: ValueKey(subtitle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
              ),
              if (s.syncIssue != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _repository.retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _outcome == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: _OutcomeBanner(outcome: _outcome!),
                      ),
              ),
              const SizedBox(height: 24),
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: SwipeToConfirm(
                  label: actionLabel,
                  icon: wantsLock ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: wantsLock ? AppColors.secure : AppColors.open,
                  enabled: canAct,
                  onConfirmed: () => _run(wantsLock),
                ),
              ),
              if (s.isLockout && s.hasReport) ...[
                const SizedBox(height: 14),
                _Notice(
                  icon: Icons.lock_clock_rounded,
                  color: AppColors.warning,
                  title: 'Keypad locked out',
                  body: '${AppConstants.maxPinAttempts} wrong PINs in a row. The keypad is paused for '
                      '${AppConstants.lockoutTimeSeconds} s. The app still works.',
                ),
              ],
              const SizedBox(height: 22),
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'DOOR',
                        value: !s.hasReport ? '—' : (s.doorClosed ? 'Closed' : 'Open'),
                        icon: Icons.door_front_door_outlined,
                        color: !confirmed ? null : (s.doorClosed ? AppColors.secure : AppColors.warning),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: 'LINK',
                        value: confirmed ? 'Online' : 'Offline',
                        detail: s.lastHeartbeat != null ? 'seen ${agoShort(s.lastHeartbeat!)}' : null,
                        icon: confirmed ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: confirmed ? AppColors.secure : AppColors.offline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'LAST ACTION',
                        value: s.hasReport && s.lastMethod.isNotEmpty ? s.lastMethodLabel : '—',
                        detail: s.hasReport ? agoShort(s.lastUpdated) : null,
                        icon: Icons.touch_app_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        label: 'KEYPAD',
                        value: !s.hasReport ? '—' : (s.isLockout ? 'Locked out' : 'Ready'),
                        icon: Icons.dialpad_rounded,
                        color: !confirmed ? null : (s.isLockout ? AppColors.warning : AppColors.secure),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: Text('RECENT ACTIVITY', style: AppTheme.label())),
                  TextButton(
                    onPressed: widget.onNavigateToHistory ??
                        () => Navigator.of(context).pushNamed(AppConstants.routeHistory),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('View all'), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 16)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_recentEvents.isEmpty)
                const Panel(
                  child: Text(
                    'No activity yet. Lock, unlock and door events will appear here.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
                  ),
                )
              else
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < _recentEvents.length; i++)
                        Reveal(
                          key: ValueKey(_recentEvents[i].id),
                          delay: Duration(milliseconds: 260 + 50 * i),
                          child: EventTile(
                            event: _recentEvents[i],
                            trailing: agoShort(_recentEvents[i].timestamp),
                            showLine: i < _recentEvents.length - 1,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildPendingRequestCard(AccessRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.brand, size: 20),
              const SizedBox(width: 8),
              Text('ACCESS REQUEST', style: AppTheme.label(color: AppColors.brand)),
              const Spacer(),
              Text(agoShort(req.requestedAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            req.email,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'UID: ${req.uid}',
            style: AppTheme.mono(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                  onPressed: () async {
                    await _repository.approveRequest(req.uid);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Access approved for ${req.email}')),
                      );
                    }
                  },
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _repository.rejectRequest(req.uid);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Request declined for ${req.email}')),
                      );
                    }
                  },
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestAccessView(BuildContext context, LockAccess access) {
    final pending = access.isPendingApproval;
    final rejected = access.isRequestRejected;
    final email = AuthService.instance.currentUser?.email ?? 'User';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        tint: pending ? AppColors.warning : AppColors.offline,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    const BrandMark(size: 28),
                    const Spacer(),
                    Pill(
                      label: pending ? 'PENDING' : (rejected ? 'DECLINED' : 'RESTRICTED'),
                      color: pending ? AppColors.warning : (rejected ? AppColors.alarm : AppColors.offline),
                      icon: pending ? Icons.hourglass_top_rounded : Icons.lock_outline_rounded,
                    ),
                  ],
                ),
                const Spacer(),
                LockOrb(
                  locked: true,
                  pending: _submittingRequest,
                  dim: true,
                  color: pending ? AppColors.warning : (rejected ? AppColors.alarm : AppColors.offline),
                  celebrate: 0,
                  size: 200,
                ),
                const SizedBox(height: 24),
                Text(
                  pending
                      ? 'Request Pending'
                      : (rejected ? 'Access Declined' : 'Private Lock'),
                  style: AppTheme.display(fontSize: 32, letterSpacing: -1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  pending
                      ? 'Your request to link to this smart lock was sent to the owner ($email).\nYou will automatically get access once accepted.'
                      : (rejected
                          ? 'The lock owner declined your access request. You can submit another request if this was a mistake.'
                          : 'This smart lock is protected. You must request access and be approved by the owner to control it.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.5),
                ),
                const SizedBox(height: 32),
                if (pending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                        ),
                        SizedBox(width: 12),
                        Text('Waiting for owner approval...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_repository.isSimulation) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(220, 46),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Approve Access as Owner (Demo)'),
                      onPressed: () async {
                        await _repository.approveRequest(AuthService.instance.currentUser?.uid ?? 'demo-user');
                      },
                    ),
                  ],
                ]
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _submittingRequest ? null : _submitRequest,
                    icon: _submittingRequest
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(_submittingRequest ? 'Sending Request...' : (rejected ? 'Request Access Again' : 'Request Access to Lock')),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => _repository.retry(),
                  child: const Text('Refresh Status', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  final CommandOutcome outcome;

  const _OutcomeBanner({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String title) = switch (outcome.result) {
      CommandResult.succeeded => (Icons.check_circle_rounded, AppColors.secure, 'Done'),
      CommandResult.rejected => (Icons.block_rounded, AppColors.warning, 'Refused by the lock'),
      CommandResult.failed => (Icons.error_outline_rounded, AppColors.alarm, 'Didn’t go through'),
      CommandResult.timedOut => (Icons.hourglass_disabled_rounded, AppColors.offline, 'No answer from the lock'),
    };
    return _Notice(icon: icon, color: color, title: title, body: outcome.message);
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Notice({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.35),
      color: Color.alphaBlend(color.withValues(alpha: 0.06), AppColors.surface),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color? color;

  const _Stat({required this.label, required this.value, required this.icon, this.detail, this.color});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 7),
              Expanded(child: Text(label, style: AppTheme.label())),
              if (color != null) PulseDot(color: color!, active: false, size: 6),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              value,
              key: ValueKey(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.display(fontSize: 18, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(detail ?? ' ', style: AppTheme.mono(fontSize: 11.5)),
        ],
      ),
    );
  }
}
