import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_state.dart';
import '../models/security_event.dart';
import '../repositories/mock_lock_repository.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../widgets/bolt_dial.dart';
import '../widgets/event_tile.dart';
import '../widgets/hold_button.dart';
import '../widgets/screen_header.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;

  const DashboardScreen({super.key, this.onNavigateToHistory});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = MockLockRepository.instance;
  late DoorLockState _lockState;
  late List<SecurityEvent> _recentEvents;
  StreamSubscription<DoorLockState>? _stateSub;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _lockState = _repository.currentState;
    _recentEvents = _repository.currentEvents.take(3).toList();
    _stateSub = _repository.stateStream.listen((state) {
      if (mounted) setState(() => _lockState = state);
    });
    _eventsSub = _repository.eventsStream.listen((events) {
      if (mounted) setState(() => _recentEvents = events.take(3).toList());
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _run(bool lock) async {
    final ok = lock ? await _repository.sendLockCommand() : await _repository.sendUnlockCommand();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Close the door before locking.')),
    );
  }

  void _openSimulation() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<DoorLockState>(
        stream: _repository.stateStream,
        initialData: _repository.currentState,
        builder: (ctx, snap) {
          final s = snap.data!;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulation',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Test how the app reacts without the ESP32.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Door is open'),
                    value: !s.doorClosed,
                    onChanged: (_) => _repository.toggleDoorSensor(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lock is offline'),
                    value: !s.isOnline,
                    onChanged: (_) => _repository.toggleConnection(),
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
    final offline = !s.isOnline;
    final color = s.isLocked
        ? AppColors.secure
        : s.isUnlocked
            ? AppColors.open
            : AppColors.warning;
    final title = s.isActionPending
        ? 'Sending…'
        : s.isLocked
            ? 'Locked'
            : s.isUnlocked
                ? 'Unlocked'
                : 'Unknown';
    final subtitle = s.isActionPending
        ? (s.pendingActionMessage ?? 'Waiting for the lock to confirm')
        : offline
            ? 'Offline. Showing the last known state.'
            : 'Updated ${agoLong(s.lastUpdated)}';

    final wantsLock = !s.isLocked;
    final blockedByDoor = wantsLock && !s.doorClosed;
    final canAct = !offline && !s.isActionPending && !blockedByDoor;
    final String actionLabel;
    if (offline) {
      actionLabel = 'Lock is offline';
    } else if (s.isActionPending) {
      actionLabel = 'Waiting for the lock';
    } else if (blockedByDoor) {
      actionLabel = 'Close the door to lock';
    } else {
      actionLabel = wantsLock ? 'Hold to lock' : 'Hold to unlock';
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.delayed(const Duration(milliseconds: 600)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              ScreenHeader(
                title: 'Front door',
                subtitle: AppConstants.appName,
                trailing: IconButton(
                  tooltip: 'Simulation',
                  icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                  onPressed: _openSimulation,
                ),
              ),
              if (s.burglarAlarmActive) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.alarm.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.alarm.withValues(alpha: 0.7)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.crisis_alert_rounded, color: AppColors.alarm),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarm is sounding',
                              style: TextStyle(
                                color: AppColors.alarm,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'The door was opened while locked.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: BoltDial(
                  locked: s.isLocked,
                  pending: s.isActionPending,
                  dim: offline,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    color: offline ? AppColors.textSecondary : color,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                  child: Text(title),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              HoldButton(
                label: actionLabel,
                icon: wantsLock ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: wantsLock ? AppColors.secure : AppColors.open,
                enabled: canAct,
                duration: Duration(milliseconds: wantsLock ? 450 : 800),
                onConfirmed: () => _run(wantsLock),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Fact(
                          label: 'Door',
                          value: s.doorClosed ? 'Closed' : 'Open',
                          dot: s.doorClosed ? AppColors.secure : AppColors.warning,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _Fact(
                          label: 'Connection',
                          value: s.isOnline ? 'Online' : 'Offline',
                          dot: s.isOnline ? AppColors.secure : AppColors.alarm,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _Fact(label: 'Last used', value: s.lastMethod)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent activity',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToHistory ??
                        () => Navigator.of(context).pushNamed(AppConstants.routeHistory),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_recentEvents.isEmpty)
                const Text(
                  'No activity yet. Lock and unlock events will show up here.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                )
              else
                for (var i = 0; i < _recentEvents.length; i++)
                  EventTile(
                    event: _recentEvents[i],
                    trailing: agoShort(_recentEvents[i].timestamp),
                    showLine: i < _recentEvents.length - 1,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color? dot;

  const _Fact({required this.label, required this.value, this.dot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
