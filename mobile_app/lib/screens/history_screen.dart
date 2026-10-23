import 'dart:async';
import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../repositories/mock_lock_repository.dart';
import '../theme/app_colors.dart';
import '../utils/time_format.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/event_tile.dart';
import '../widgets/screen_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = MockLockRepository.instance;
  late List<SecurityEvent> _allEvents;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;

  int _filter = 0;
  bool _simulateLoading = false;
  bool _simulateError = false;

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

  List<Object> get _rows {
    final out = <Object>[];
    String? last;
    for (final e in _filtered) {
      final d = dayLabel(e.timestamp);
      if (d != last) {
        out.add(d);
        last = d;
      }
      out.add(e);
    }
    return out;
  }

  void _simulate(String val) {
    setState(() {
      if (val == 'loading') {
        _simulateLoading = true;
        _simulateError = false;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _simulateLoading = false);
        });
      } else if (val == 'error') {
        _simulateError = !_simulateError;
        _simulateLoading = false;
      } else {
        _simulateError = false;
        _simulateLoading = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: ScreenHeader(
                title: 'Activity',
                subtitle: '${_allEvents.length} events recorded',
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                  tooltip: 'Simulate states',
                  onSelected: _simulate,
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'loading', child: Text('Show loading')),
                    PopupMenuItem(
                      value: 'error',
                      child: Text(_simulateError ? 'Clear error' : 'Show error'),
                    ),
                    const PopupMenuItem(value: 'reset', child: Text('Reset')),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(value: 0, label: Text('All')),
                    ButtonSegment(
                      value: 1,
                      label: Text(_alertCount > 0 ? 'Alerts ($_alertCount)' : 'Alerts'),
                    ),
                    const ButtonSegment(value: 2, label: Text('Normal')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_simulateLoading) {
      return const AppLoadingIndicator(message: 'Loading activity…');
    }

    if (_simulateError) {
      return AppErrorView(
        title: 'Couldn’t load activity',
        message: 'The app can’t reach the database. Check your connection and try again.',
        onRetry: () => setState(() => _simulateError = false),
      );
    }

    final rows = _rows;
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text(
                'Nothing here',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'No events match this filter. Switch to All to see every event.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 8 : 14, bottom: 14),
            child: Text(
              row,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final event = row as SecurityEvent;
        final isLast = i == rows.length - 1 || rows[i + 1] is String;
        return EventTile(
          event: event,
          trailing: clock(event.timestamp),
          showLine: !isLast,
          detailed: true,
        );
      },
    );
  }
}
