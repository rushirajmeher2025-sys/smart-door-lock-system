import 'dart:async';
import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../repositories/lock_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/backdrop.dart';
import '../widgets/event_tile.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/segment_toggle.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LockRepository _repository = lockRepository();
  late List<SecurityEvent> _allEvents;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;

  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _allEvents = _repository.currentEvents;
    _eventsSub = _repository.eventsStream.listen((events) {
      if (mounted) setState(() => _allEvents = events);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  int get _alertCount => _allEvents.where((e) => e.isWarningOrAlarm).length;

  List<SecurityEvent> get _filtered {
    if (_filter == 1) return _allEvents.where((e) => e.isWarningOrAlarm).toList();
    if (_filter == 2) return _allEvents.where((e) => !e.isWarningOrAlarm).toList();
    return _allEvents;
  }

  /// Day headers followed by that day's events.
  List<(String, List<SecurityEvent>)> get _groups {
    final out = <(String, List<SecurityEvent>)>[];
    for (final e in _filtered) {
      final d = dayLabel(e.timestamp);
      if (out.isEmpty || out.last.$1 != d) out.add((d, []));
      out.last.$2.add(e);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: ScreenHeader(
                  title: 'Activity',
                  subtitle: _repository.eventsLoaded ? '${_allEvents.length} events · newest first' : 'Loading',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentToggle(
                  labels: ['All', _alertCount > 0 ? 'Alerts · $_alertCount' : 'Alerts', 'Normal'],
                  index: _filter,
                  onChanged: (i) => setState(() => _filter = i),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey(_filter), child: _body()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_repository.eventsLoaded) {
      return const AppLoadingIndicator(message: 'Loading activity…');
    }

    if (_repository.eventsError != null && _allEvents.isEmpty) {
      return AppErrorView(
        title: 'Couldn’t load activity',
        message: _repository.eventsError!,
        onRetry: _repository.retry,
      );
    }

    final groups = _groups;
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_toggle_off_rounded, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 14),
              Text(_allEvents.isEmpty ? 'No activity yet' : 'Nothing here', style: AppTheme.display(fontSize: 18, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(
                _allEvents.isEmpty
                    ? 'Events from the lock show up here as they happen.'
                    : 'No events match this filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    var row = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        for (final (day, events) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(day.toUpperCase(), style: AppTheme.label()),
          ),
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++)
                  Reveal(
                    key: ValueKey(events[i].id),
                    delay: Duration(milliseconds: (row++).clamp(0, 12) * 40),
                    child: EventTile(
                      event: events[i],
                      trailing: clock(events[i].timestamp),
                      showLine: i < events.length - 1,
                      detailed: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
