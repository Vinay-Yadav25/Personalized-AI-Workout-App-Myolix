import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/routine_provider.dart';
import '../providers/auth_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────
DateTime? _parseDate(String s) {
  try { return DateTime.parse(s); } catch (_) { return null; }
}

// FIX: derive weekday name from the REAL calendar date's weekday,
//      not from a hardcoded position array (1 → MON was wrong when
//      the routine didn't start on a Monday).
String _weekdayShort(DateTime d) =>
    ['MON','TUE','WED','THU','FRI','SAT','SUN'][d.weekday - 1];

String _monthShort(int m) =>
    ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

// ─── RoutineScreen ────────────────────────────────────────────────────────────
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int _selectedDayIdx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToToday());
  }

  void _jumpToToday() {
    final rp      = context.read<RoutineProvider>();
    final weekStart = _weekStart(rp);
    if (weekStart == null) return;

    final todayNum = DateTime.now()
        .difference(DateTime(weekStart.year, weekStart.month, weekStart.day))
        .inDays + 1;

    final idx = rp.days.indexWhere(
            (d) => (d['day_of_week'] as int) == todayNum.clamp(1, 7));
    if (idx >= 0 && mounted) setState(() => _selectedDayIdx = idx);
  }

  // start_date is always updated on Continue, so it always means
  // "start of the current routine week" — use it directly.
  DateTime? _weekStart(RoutineProvider rp) =>
      _parseDate(rp.routine?['start_date'] as String? ?? '');

  @override
  Widget build(BuildContext context) {
    final rp   = context.watch<RoutineProvider>();
    final auth = context.watch<AuthProvider>();

    if (rp.loading && rp.routine == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rp.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(rp.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: rp.loadCurrent, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (rp.routine == null || rp.days.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.fitness_center, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text('No active routine',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: rp.generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Routine'),
          ),
        ]),
      );
    }

    final weekStart   = _weekStart(rp);
    final today       = DateTime.now();
    final todayStripped = DateTime(today.year, today.month, today.day);
    final todayDayNum = weekStart != null
        ? todayStripped
        .difference(DateTime(weekStart.year, weekStart.month, weekStart.day))
        .inDays + 1
        : -1;

    final safeIdx   = _selectedDayIdx.clamp(0, rp.days.length - 1);
    final selDay    = rp.days[safeIdx] as Map;
    final selDayNum = selDay['day_of_week'] as int;
    final selDate   = weekStart?.add(Duration(days: selDayNum - 1));
    final isToday   = selDayNum == todayDayNum;
    final isPast    = todayDayNum != -1 && selDayNum < todayDayNum;
    final exercises  = (selDay['exercises'] as List?) ?? [];
    // FIX: 'Rest' (legacy, no exercises) is now only a true blank day.
    //      'Active Recovery' (new Sunday slot) HAS light cardio exercises,
    //      so it must NOT be treated as empty/rest — it renders as a
    //      normal (lighter) workout day with its own visual styling.
    final isRecovery = selDay['focus'] == 'Active Recovery';
    final isRest      = exercises.isEmpty && !isRecovery;

    final totalSets   = exercises.fold<int>(
        0, (s, e) => s + ((e['sets'] as num?)?.toInt() ?? 3));
    // Recovery day duration is just the sum of its light-cardio durations
    final workoutMins = isRecovery ? (exercises.length * 18) : (totalSets * 1.5).ceil();
    const warmupMins  = 10;
    final totalMins   = isRest ? 0 : (isRecovery ? workoutMins : workoutMins + warmupMins);

    final showBanner = rp.isCompleted ||
        (rp.totalExercises > 0 && rp.completedExercises == rp.totalExercises);

    // FIX: SafeArea ensures the header never hides behind the status bar
    return SafeArea(
      child: Column(
        children: [
          _PlanHeader(auth: auth, rp: rp),
          _WeekStrip(
            days:          rp.days,
            weekStart:     weekStart,
            todayDayNum:   todayDayNum,
            selectedIdx:   safeIdx,
            onDaySelected: (i) => setState(() => _selectedDayIdx = i),
          ),
          Expanded(
            child: isRest
                ? _RestDayView(dayDate: selDate)
                : _WorkoutDayView(
              day:         selDay,
              exercises:   exercises,
              isToday:     isToday,
              isPast:      isPast,
              isRecovery:  isRecovery,
              totalMins:   totalMins,
              warmupMins:  warmupMins,
              workoutMins: workoutMins,
              showBanner:  showBanner,
              rp:          rp,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan header ──────────────────────────────────────────────────────────────
class _PlanHeader extends StatelessWidget {
  final AuthProvider    auth;
  final RoutineProvider rp;
  const _PlanHeader({required this.auth, required this.rp});

  // Mirrors the backend's 4-week mesocycle so the user can see
  // which training phase they're currently in.
  static const _phaseNames = {
    1: 'Hypertrophy',
    2: 'Volume',
    3: 'Intensity',
    4: 'Deload',
  };
  static const _phaseColors = {
    1: Color(0xFF6C5CE7),
    2: Color(0xFF00CEC9),
    3: Color(0xFFFF6B6B),
    4: Color(0xFFFDCB6E),
  };

  @override
  Widget build(BuildContext context) {
    final weekNum = (rp.routine?['week_number'] as num?)?.toInt() ?? 1;
    var phase = weekNum % 4;
    if (phase == 0) phase = 4;
    final phaseName  = _phaseNames[phase]!;
    final phaseColor = _phaseColors[phase]!;

    return Container(
      color: const Color(0xFF0F0F1E),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              "${auth.userName ?? 'My'}'s Workout Plan",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Row(children: [
              _dot(const Color(0xFFFF6B6B)),
              const SizedBox(width: 6),
              Text('Week $weekNum',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(width: 8),
              _dot(Colors.white38),
              const SizedBox(width: 6),
              Text('${rp.completedExercises}/${rp.totalExercises} done',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(width: 8),
              _dot(Colors.white38),
              const SizedBox(width: 6),
              const Text('7 Days',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            // Periodization phase badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: phaseColor.withOpacity(0.4)),
              ),
              child: Text(
                '$phaseName Phase',
                style: TextStyle(
                    color: phaseColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ]),
    );
  }

  Widget _dot(Color c) => Container(
      width: 6, height: 6,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ─── Week strip ───────────────────────────────────────────────────────────────
class _WeekStrip extends StatelessWidget {
  final List                days;
  final DateTime?           weekStart;
  final int                 todayDayNum;
  final int                 selectedIdx;
  final void Function(int)  onDaySelected;

  const _WeekStrip({
    required this.days,
    required this.weekStart,
    required this.todayDayNum,
    required this.selectedIdx,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1E),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(days.length, (i) {
            final day     = days[i] as Map;
            final dayNum  = day['day_of_week'] as int;

            // FIX: compute the actual calendar date for this slot
            final dayDate = weekStart?.add(Duration(days: dayNum - 1));

            // FIX: use dayDate.weekday (1=Mon…7=Sun) for the label,
            //      NOT dayNum-1 which assumed day 1 was always Monday
            final dayLabel = dayDate != null
                ? _weekdayShort(dayDate)
                : ['MON','TUE','WED','THU','FRI','SAT','SUN']
            [(dayNum - 1).clamp(0, 6)];

            final dateNum  = dayDate?.day ?? dayNum;
            final isToday  = dayNum == todayDayNum;
            final isSelected = i == selectedIdx;

            final exList   = (day['exercises'] as List?) ?? [];
            final allDone  = exList.isNotEmpty &&
                exList.every((e) => e['is_completed'] == 1);

            return GestureDetector(
              onTap: () => onDaySelected(i),
              child: Container(
                width: 52,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: [
                  // Red dot above today
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFFFF6B6B)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Calendar date number
                  Text(
                    '$dateNum',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: isSelected
                          ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                  ),
                  // Weekday label  — NOW SHOWS CORRECT REAL DAY
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF00CEC9) : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Underline (selected) / check (all done)
                  if (allDone)
                    const Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF00CEC9))
                  else if (isSelected)
                    Container(
                      height: 2, width: 28,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF6C5CE7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(height: 2),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Rest day ─────────────────────────────────────────────────────────────────
class _RestDayView extends StatelessWidget {
  final DateTime? dayDate;
  const _RestDayView({this.dayDate});

  @override
  Widget build(BuildContext context) {
    final label = dayDate != null
        ? '${_weekdayShort(dayDate!)}, ${_monthShort(dayDate!.month)} ${dayDate!.day}'
        : '';
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('😴', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('Rest Day',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
        const SizedBox(height: 8),
        const Text('Recovery is part of training.',
            style: TextStyle(color: Colors.white54)),
      ]),
    );
  }
}

// ─── Workout day view ─────────────────────────────────────────────────────────
class _WorkoutDayView extends StatefulWidget {
  final Map               day;
  final List              exercises;
  final bool              isToday, isPast, isRecovery, showBanner;
  final int               totalMins, warmupMins, workoutMins;
  final RoutineProvider   rp;

  const _WorkoutDayView({
    required this.day,
    required this.exercises,
    required this.isToday,
    required this.isPast,
    required this.isRecovery,
    required this.totalMins,
    required this.warmupMins,
    required this.workoutMins,
    required this.showBanner,
    required this.rp,
  });

  @override
  State<_WorkoutDayView> createState() => _WorkoutDayViewState();
}

class _WorkoutDayViewState extends State<_WorkoutDayView> {
  bool _warmupExpanded  = false;
  bool _workoutExpanded = true;

  @override
  Widget build(BuildContext context) {
    final canToggle = widget.isToday;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Focus label + total time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text(widget.day['focus'] ?? '',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  if (widget.isRecovery) ...[
                    const SizedBox(width: 8),
                    const Text('🌿', style: TextStyle(fontSize: 18)),
                  ],
                ]),
                Text('${widget.totalMins} MINS',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ],
            ),

            // FIX: recovery days get an explanatory subtitle instead of
            //      jumping straight into a Warm Up section that doesn't
            //      apply to light cardio days
            if (widget.isRecovery) ...[
              const SizedBox(height: 4),
              const Text(
                'Light cardio to keep blood flowing — walk, jog, or cycle '
                    'at an easy pace.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),

            // Warm Up — skipped entirely for recovery days
            if (!widget.isRecovery) ...[
              _SectionHeader(
                title: 'Warm Up',
                mins: widget.warmupMins,
                expanded: _warmupExpanded,
                onToggle: () =>
                    setState(() => _warmupExpanded = !_warmupExpanded),
              ),
              if (_warmupExpanded) ...[
                const SizedBox(height: 8),
                _WarmUpCard(),
              ],
              const Divider(color: Colors.white12, height: 24),
            ],

            // Workout / Recovery activities
            _SectionHeader(
              title: widget.isRecovery ? 'Recovery Activities' : 'Workout',
              mins: widget.workoutMins,
              expanded: _workoutExpanded,
              onToggle: () =>
                  setState(() => _workoutExpanded = !_workoutExpanded),
            ),
            if (_workoutExpanded) ...[
              const SizedBox(height: 12),
              for (final ex in widget.exercises)
                _ExerciseCard(
                  ex: ex,
                  canToggle: canToggle,
                  rp: widget.rp,
                  isRecovery: widget.isRecovery,
                ),
            ],

            if (widget.showBanner) ...[
              const SizedBox(height: 16),
              _CompletionBanner(rp: widget.rp),
            ],
          ],
        ),
      ),

      // Fixed bottom buttons
      if (!widget.showBanner)
        _BottomActions(
          isToday: widget.isToday,
          isPast:  widget.isPast,
          rp:      widget.rp,
        ),
    ]);
  }
}

// ─── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int    mins;
  final bool   expanded;
  final VoidCallback onToggle;
  const _SectionHeader({
    required this.title, required this.mins,
    required this.expanded, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      Text('$mins MINS',
          style: const TextStyle(color: Colors.white60, fontSize: 13)),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(expanded ? Icons.keyboard_arrow_up : Icons.add,
              color: Colors.white, size: 18),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onToggle,
        child: Icon(
          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: Colors.white60,
        ),
      ),
    ]);
  }
}

// ─── Warm up card ─────────────────────────────────────────────────────────────
class _WarmUpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.directions_run,
            color: Colors.orange, size: 28),
      ),
      title: const Text('Light Cardio + Stretch',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('5 min jog • 5 min dynamic stretch',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: const Icon(Icons.more_vert, color: Colors.white38),
    ),
  );
}

// ─── Exercise card ────────────────────────────────────────────────────────────
class _ExerciseCard extends StatelessWidget {
  final Map             ex;
  final bool            canToggle;
  final bool            isRecovery;
  final RoutineProvider rp;
  const _ExerciseCard({
    required this.ex,
    required this.canToggle,
    required this.rp,
    this.isRecovery = false,
  });

  static const _colors = {
    'Chest':     Color(0xFF6C5CE7), 'Back':      Color(0xFF0984E3),
    'Legs':      Color(0xFF00B894), 'Shoulders': Color(0xFFE17055),
    'Arms':      Color(0xFFFD79A8), 'Triceps':   Color(0xFFA29BFE),
    'Biceps':    Color(0xFF74B9FF), 'Core':      Color(0xFF55EFC4),
    'Cardio':    Color(0xFFFF7675), 'FullBody':  Color(0xFFFDCB6E),
  };
  static const _icons = {
    'Chest': Icons.fitness_center,  'Back':      Icons.airline_seat_flat,
    'Legs':  Icons.directions_walk, 'Shoulders': Icons.accessibility_new,
    'Arms':  Icons.sports_handball, 'Triceps':   Icons.sports_handball,
    'Biceps':Icons.sports_handball, 'Core':      Icons.crop_rotate,
    'Cardio':Icons.directions_run,  'FullBody':  Icons.sports_gymnastics,
  };

  // Parses "12,10,8,6" → "12 Reps • 10 Reps • 8 Reps • 6 Reps"
  // Parses "30s,30s,30s" → "30s • 30s • 30s" (no "Reps" suffix for time)
  // Falls back to repeating a single legacy value across `sets` count.
  static String _buildRepLabel(String rawReps, int sets) {
    final parts = rawReps
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final display = parts.length > 1
        ? parts
        : List.generate(sets, (_) => parts.isNotEmpty ? parts.first : rawReps);

    return display.map((p) {
      final isSeconds = p.toLowerCase().endsWith('s') &&
          !p.toLowerCase().contains('min');
      return isSeconds ? p : '$p Reps';
    }).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final muscle    = ex['muscle_group'] as String? ?? 'Chest';
    final color     = _colors[muscle] ?? const Color(0xFF6C5CE7);
    final icon      = _icons[muscle]  ?? Icons.fitness_center;
    final sets      = (ex['sets'] as num?)?.toInt() ?? 3;
    final rawReps   = (ex['reps'] as String? ?? '10').trim();
    final isDone    = ex['is_completed'] == 1;
    final exId      = (ex['id'] as num).toInt();
    final equipment = ex['equipment'] as String? ?? '';

    // FIX: backend now stores a per-set scheme like "12,10,8,6" (pyramid)
    //      or "30s,30s,30s" (time-based) instead of one number repeated.
    //      Parse it into individual chips; fall back to the old
    //      "repeat single value" behavior for any legacy routines
    //      generated before this change.
    final repLabel = isRecovery ? rawReps : _buildRepLabel(rawReps, sets);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: isDone
            ? Border.all(color: const Color(0xFF00CEC9), width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canToggle ? () => rp.toggleExercise(exId, !isDone) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Thumbnail
            Stack(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              if (isDone)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00CEC9).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 28),
                  ),
                ),
            ]),
            const SizedBox(width: 14),

            // Name + reps
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  ex['name'] ?? '',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: isDone ? Colors.white54 : Colors.white,
                    decoration: isDone
                        ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(repLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (equipment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.fitness_center,
                        size: 10, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(equipment,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ]),
                ],
              ]),
            ),

            // Three-dot menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white38),
              color: const Color(0xFF2A2A3E),
              onSelected: (v) {
                if (v == 'toggle' && canToggle) rp.toggleExercise(exId, !isDone);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      isDone ? Icons.undo : Icons.check_circle_outline,
                      size: 18,
                      color: isDone
                          ? Colors.redAccent : const Color(0xFF00CEC9),
                    ),
                    const SizedBox(width: 8),
                    Text(isDone ? 'Mark undone' : 'Mark done'),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Bottom actions ───────────────────────────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final bool isToday, isPast;
  final RoutineProvider rp;
  const _BottomActions(
      {required this.isToday, required this.isPast, required this.rp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/onboarding'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('EDIT',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 1.2)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isToday ? () => _startSheet(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isToday
                  ? const Color(0xFFFF6B6B)
                  : Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isToday ? 'START' : isPast ? 'DONE' : 'LOCKED',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2),
            ),
          ),
        ),
      ]),
    );
  }

  void _startSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.play_circle_filled,
              size: 56, color: Color(0xFFFF6B6B)),
          const SizedBox(height: 12),
          const Text("Let's Go!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Tap each exercise to mark it done.\nGood luck! 💪",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('GOT IT',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Completion banner ────────────────────────────────────────────────────────
class _CompletionBanner extends StatelessWidget {
  final RoutineProvider rp;
  const _CompletionBanner({required this.rp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Icon(Icons.emoji_events, color: Colors.white, size: 48),
        const SizedBox(height: 8),
        const Text('🎉 Weekly Routine Completed!',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Ready for the next step?',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: rp.loading ? null : () async {
                await rp.continueRoutine();
                if (!context.mounted) return;
                if (rp.error != null) ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: ${rp.error}')));
              },
              icon: const Icon(Icons.repeat, color: Colors.white),
              label: const Text('Continue',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: rp.loading ? null : () async {
                await rp.generateNewRoutine();
                if (!context.mounted) return;
                if (rp.error != null) ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: ${rp.error}')));
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('New Routine'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ]),
    );
  }
}