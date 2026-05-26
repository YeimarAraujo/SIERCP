import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/l10n/app_localizations.dart';

// ─── Domain ───────────────────────────────────────────────────────────────────

enum _EventType { quiz, session, certificate }

class _CalEvent {
  final String id;
  final String title;
  final DateTime date;
  final _EventType type;
  final String? subtitle;

  const _CalEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.subtitle,
  });
}

Color _typeColor(_EventType t) {
  switch (t) {
    case _EventType.quiz:
      return AppColors.accent;
    case _EventType.session:
      return AppColors.brand;
    case _EventType.certificate:
      return AppColors.green;
  }
}

IconData _typeIcon(_EventType t) {
  switch (t) {
    case _EventType.quiz:
      return Icons.quiz_outlined;
    case _EventType.session:
      return Icons.monitor_heart_outlined;
    case _EventType.certificate:
      return Icons.workspace_premium_outlined;
  }
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _calendarEventsProvider =
    FutureProvider.autoDispose<Map<String, List<_CalEvent>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final db = FirebaseFirestore.instance;
  final uid = user.id;

  final results = await Future.wait([
    // Quiz sessions
    db
        .collection('quizSessions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get(),
    // Practical sessions
    db
        .collection('sessions')
        .where('studentId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .limit(100)
        .get(),
    // Certificates
    db
        .collection('certificates')
        .where('userId', isEqualTo: uid)
        .orderBy('issuedAt', descending: true)
        .limit(100)
        .get(),
  ]);

  final events = <_CalEvent>[];

  for (final doc in results[0].docs) {
    final d = doc.data();
    final ts = d['createdAt'] as Timestamp?;
    if (ts == null) continue;
    final score = d['score'] as num?;
    events.add(_CalEvent(
      id: doc.id,
      title: d['topicTitle'] as String? ?? 'Evaluación',
      date: ts.toDate(),
      type: _EventType.quiz,
      subtitle: score != null ? '${score.toInt()}%' : null,
    ));
  }

  for (final doc in results[1].docs) {
    final d = doc.data();
    final ts = d['startedAt'] as Timestamp?;
    if (ts == null) continue;
    final score = d['score'] as num?;
    events.add(_CalEvent(
      id: doc.id,
      title: d['scenarioTitle'] as String? ?? 'Sesión RCP',
      date: ts.toDate(),
      type: _EventType.session,
      subtitle: score != null ? '${score.toInt()}%' : null,
    ));
  }

  for (final doc in results[2].docs) {
    final d = doc.data();
    final ts = d['issuedAt'] as Timestamp?;
    if (ts == null) continue;
    events.add(_CalEvent(
      id: doc.id,
      title: d['courseTitle'] as String? ?? 'Certificado',
      date: ts.toDate(),
      type: _EventType.certificate,
    ));
  }

  final grouped = <String, List<_CalEvent>>{};
  for (final e in events) {
    final key = _dateKey(e.date);
    grouped.putIfAbsent(key, () => []).add(e);
  }
  return grouped;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(_calendarEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.calendarTitle),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_calendarEventsProvider),
            tooltip: loc.calendarRetry,
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(loc.calendarLoading,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.red),
              const SizedBox(height: 12),
              Text(loc.calendarError, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_calendarEventsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc.calendarRetry),
              ),
            ],
          ),
        ),
        data: (events) => Column(
          children: [
            _MonthHeader(
              month: _month,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            _WeekDayLabels(),
            _MonthGrid(
              month: _month,
              events: events,
              selectedDay: _selectedDay,
              onDayTap: (d) => setState(() => _selectedDay = d),
            ),
            const Divider(height: 1),
            Expanded(
              child: _DayPanel(
                day: _selectedDay,
                events: events,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month header ─────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader(
      {required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'es').format(month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              label[0].toUpperCase() + label.substring(1),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─── Week day labels ──────────────────────────────────────────────────────────

class _WeekDayLabels extends StatelessWidget {
  static const _days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _days
            .map(
              (d) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Month grid ───────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, List<_CalEvent>> events;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  const _MonthGrid({
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday 1=Mon..7=Sun → convert to 0=Sun..6=Sat
    final startOffset = (firstDay.weekday % 7);

    final cells = <Widget>[];

    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = _dateKey(date);
      final dayEvents = events[key] ?? [];
      final isToday = date == today;
      final isSelected = selectedDay != null &&
          date.year == selectedDay!.year &&
          date.month == selectedDay!.month &&
          date.day == selectedDay!.day;

      cells.add(_DayCell(
        day: day,
        events: dayEvents,
        isToday: isToday,
        isSelected: isSelected,
        onTap: () => onDayTap(date),
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final cellHeight = cellWidth.clamp(0.0, 46.0);
        final ratio = cellWidth / cellHeight;
        return GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 3,
          crossAxisSpacing: 0,
          childAspectRatio: ratio,
          children: cells,
        );
      },
    );
  }
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final List<_CalEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvents = events.isNotEmpty;

    Color? bgColor;
    Color textColor = theme.colorScheme.onSurface;

    if (isSelected) {
      bgColor = AppColors.brand;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppColors.brand.withValues(alpha: 0.15);
      textColor = AppColors.brand;
    }

    // Collect unique event types for dots
    final types = events.map((e) => e.type).toSet().toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (hasEvents) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: types.take(3).map((t) {
                  final color = isSelected ? Colors.white70 : _typeColor(t);
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Day panel ────────────────────────────────────────────────────────────────

class _DayPanel extends StatelessWidget {
  final DateTime? day;
  final Map<String, List<_CalEvent>> events;

  const _DayPanel({required this.day, required this.events});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (day == null) {
      return Center(
        child: Text(loc.calendarNoEvents,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      );
    }

    final key = _dateKey(day!);
    final dayEvents = events[key] ?? [];
    final dateLabel = DateFormat('EEEE, d MMMM', 'es').format(day!);
    final capitalizedLabel =
        dateLabel[0].toUpperCase() + dateLabel.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                capitalizedLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2),
              ),
              if (dayEvents.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${dayEvents.length}',
                    style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (dayEvents.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 36,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
                  const SizedBox(height: 10),
                  Text(
                    loc.calendarNoEvents,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dayEvents.length,
              itemBuilder: (context, i) => _EventTile(event: dayEvents[i]),
            ),
          ),
      ],
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final _CalEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _typeColor(event.type);
    final timeLabel =
        DateFormat('HH:mm').format(event.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(event.type), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (event.subtitle != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.subtitle!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
