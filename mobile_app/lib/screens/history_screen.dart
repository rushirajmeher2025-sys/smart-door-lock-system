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

// ---------------------------------------------------------------------------
// Filter chip definitions
// ---------------------------------------------------------------------------

class _ChipDef {
  final String label;
  final String emoji;
  final Set<String> types;
  final Set<String> prefixes;

  const _ChipDef({
    required this.label,
    required this.emoji,
    required this.types,
    this.prefixes = const {},
  });

  bool matches(SecurityEvent e) {
    if (types.contains(e.type)) return true;
    for (final p in prefixes) {
      if (e.type.startsWith(p)) return true;
    }
    return false;
  }
}

const List<_ChipDef> _chips = [
  _ChipDef(label: 'Lock', emoji: '🔒', types: {'lock', 'unlock'}),
  _ChipDef(label: 'PIN', emoji: '⌨️', types: {'failed_attempt', 'lockout', 'pin_changed'}),
  _ChipDef(label: 'Door', emoji: '🚪', types: {'door_opened', 'door_closed', 'door_warning'}),
  _ChipDef(label: 'Connection', emoji: '🌐', types: {'lock_online', 'lock_reconnected'}, prefixes: {'rej_'}),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

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

  // Search
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Chips
  final Set<int> _activeChips = {};

  @override
  void initState() {
    super.initState();
    _allEvents = _repository.currentEvents;
    _eventsSub = _repository.eventsStream.listen((events) {
      if (mounted) setState(() => _allEvents = events);
    });
    _searchController.addListener(() {
      final q = _searchController.text;
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int get _alertCount => _allEvents.where((e) => e.isWarningOrAlarm).length;

  bool get _hasActiveFilters => _activeChips.isNotEmpty || _searchQuery.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _activeChips.clear();
      _searchController.clear();
      _searchQuery = '';
      _searchOpen = false;
    });
  }

  /// Events after the segment toggle.
  List<SecurityEvent> get _segmentFiltered {
    if (_filter == 1) return _allEvents.where((e) => e.isWarningOrAlarm).toList();
    if (_filter == 2) return _allEvents.where((e) => !e.isWarningOrAlarm).toList();
    return _allEvents;
  }

  /// Events after chips + search applied on top of segment.
  List<SecurityEvent> get _filtered {
    var base = _segmentFiltered;

    // Chip filter — additive (any chip matches)
    if (_activeChips.isNotEmpty) {
      base = base.where((e) {
        for (final i in _activeChips) {
          if (_chips[i].matches(e)) return true;
        }
        return false;
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.method.toLowerCase().contains(q);
      }).toList();
    }

    return base;
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ScreenHeader(
                        title: 'Activity',
                        subtitle: _repository.eventsLoaded
                            ? '${_allEvents.length} events · newest first'
                            : 'Loading',
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                        color: _searchOpen ? cs.primary : AppColors.textMuted,
                      ),
                      tooltip: _searchOpen ? 'Close search' : 'Search events',
                      onPressed: () {
                        setState(() {
                          _searchOpen = !_searchOpen;
                          if (!_searchOpen) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Search bar
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _searchOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search events…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Segment toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentToggle(
                  labels: ['All', _alertCount > 0 ? 'Alerts · $_alertCount' : 'Alerts', 'Normal'],
                  index: _filter,
                  onChanged: (i) => setState(() => _filter = i),
                ),
              ),
              const SizedBox(height: 8),

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _chips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final chip = _chips[i];
                    final selected = _activeChips.contains(i);
                    final isDark = AppColors.isDark(context);
                    final chipBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
                    final chipBorder = isDark ? AppColors.darkHairline : AppColors.lightHairline;
                    final labelColor = selected ? cs.secondary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
                    return FilterChip(
                      label: Text("${chip.emoji} ${chip.label}"),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _activeChips.add(i);
                          } else {
                            _activeChips.remove(i);
                          }
                        });
                      },
                      backgroundColor: chipBg,
                      selectedColor: cs.secondary.withValues(alpha: 0.18),
                      checkmarkColor: cs.secondary,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: labelColor,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: selected ? cs.secondary.withValues(alpha: 0.5) : chipBorder,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),

              // Clear filters button
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: _hasActiveFilters
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16, top: 2),
                          child: TextButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text('Clear filters', style: TextStyle(fontSize: 12.5)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                            onPressed: _clearFilters,
                          ),
                        ),
                      )
                    : const SizedBox(height: 6),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey((_filter, _activeChips.join(','), _searchQuery)),
                    child: _body(),
                  ),
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
        title: "Couldn't load activity",
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
