import 'dart:async';
import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../repositories/mock_lock_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading_indicator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = MockLockRepository.instance;
  late List<SecurityEvent> _allEvents;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;

  int _selectedFilterIndex = 0; // 0: All, 1: Warnings/Alarms, 2: Normal
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

  List<SecurityEvent> get _filteredEvents {
    if (_selectedFilterIndex == 1) {
      return _allEvents.where((e) => e.isWarningOrAlarm).toList();
    } else if (_selectedFilterIndex == 2) {
      return _allEvents.where((e) => !e.isWarningOrAlarm).toList();
    }
    return _allEvents;
  }

  String _formatDetailDate(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${time.day}/${time.month}/${time.year} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        actions: [
          // State simulation menu to test Loading / Error / Normal states
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Simulate UI States',
            onSelected: (val) {
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
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'loading',
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Simulate Loading State'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'error',
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: AppColors.alarm),
                    const SizedBox(width: 8),
                    Text(_simulateError ? 'Clear Error State' : 'Simulate Error State'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Reset to Normal'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                _buildFilterChip(0, 'All (${_allEvents.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Warnings & Alarms', isWarning: true),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Normal Access'),
              ],
            ),
          ),

          // Main Content Area with State Handling
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, {bool isWarning = false}) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilterIndex = index);
      },
      selectedColor: isWarning ? AppColors.alarm.withValues(alpha: 0.25) : AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? (isWarning ? AppColors.alarm : AppColors.primaryLight)
            : AppColors.border,
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_simulateLoading) {
      return const AppLoadingIndicator(message: 'Retrieving security event log...');
    }

    if (_simulateError) {
      return AppErrorView(
        title: 'Failed to Load Activity Log',
        message: 'Could not connect to Firebase Realtime Database. Check network connection.',
        onRetry: () {
          setState(() {
            _simulateError = false;
          });
        },
      );
    }

    final events = _filteredEvents;

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 54, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'No Events Found',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'There are no security events matching this filter category.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildDetailedEventCard(event);
      },
    );
  }

  Widget _buildDetailedEventCard(SecurityEvent event) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: event.isWarningOrAlarm
              ? event.color.withValues(alpha: 0.5)
              : AppColors.border,
          width: event.isWarningOrAlarm ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: event.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(event.icon, color: event.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: event.isWarningOrAlarm ? event.color : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (event.isWarningOrAlarm)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.severity == EventSeverity.alarm ? 'ALERT' : 'WARNING',
                            style: TextStyle(
                              color: event.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            event.method,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDetailDate(event.timestamp),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
