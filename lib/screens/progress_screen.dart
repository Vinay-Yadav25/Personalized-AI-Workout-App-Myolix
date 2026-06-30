import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProgressProvider>();

    if (pp.loading && pp.log.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => pp.load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stat cards ──────────────────────────────────────────────────────
          Row(children: [
            _StatCard(
              icon: Icons.calendar_today,
              label: 'Workouts',
              value: '${pp.totalWorkouts}',
              color: const Color(0xFF6C5CE7),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.check_circle_outline,
              label: 'Exercises',
              value: '${pp.totalCompleted}',
              color: const Color(0xFF00CEC9),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.percent,
              label: 'Avg',
              value: '${(pp.avgCompletion * 100).toStringAsFixed(0)}%',
              color: const Color(0xFFFD79A8),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Chart ──────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Completion Trend',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: pp.log.isEmpty
                        ? const Center(
                        child:
                        Text('No data yet — train a few sessions!'))
                        : _buildChart(pp),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Recent Activity list ────────────────────────────────────────────
          if (pp.log.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            ...pp.log.reversed.take(14).map((e) {
              final total     = ((e['total_exercises']     ?? 1) as num).toInt();
              final completed = ((e['completed_exercises'] ?? 0) as num).toInt();
              final safeTotal = total == 0 ? 1 : total;
              final pct       = (completed / safeTotal * 100).toStringAsFixed(0);
              final pctColor  = completed == 0
                  ? Colors.redAccent
                  : completed == total
                  ? const Color(0xFF00CEC9)
                  : Colors.orangeAccent;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: completed == 0
                        ? Colors.grey.shade700
                        : const Color(0xFF6C5CE7),
                    child: Icon(
                      completed == 0
                          ? Icons.close
                          : completed == total
                          ? Icons.check
                          : Icons.fitness_center,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(_formatDate(e['log_date'] ?? '')),
                  subtitle: Text('$completed of $total exercises'),
                  trailing: Text(
                    '$pct%',
                    style: TextStyle(
                        color: pctColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Chart builder ───────────────────────────────────────────────────────────
  Widget _buildChart(ProgressProvider pp) {
    // Build spots — use percentage (0.0–1.0) so Y axis is always 0–100%
    final spots = <FlSpot>[];
    for (int i = 0; i < pp.log.length; i++) {
      final total     = ((pp.log[i]['total_exercises']     ?? 1) as num).toInt();
      final completed = ((pp.log[i]['completed_exercises'] ?? 0) as num).toInt();
      final pct       = total == 0 ? 0.0 : completed / total * 100;
      spots.add(FlSpot(i.toDouble(), double.parse(pct.toStringAsFixed(1))));
    }

    // Bottom axis: show date label every N entries to avoid crowding
    final count    = spots.length;
    final step     = count <= 7 ? 1 : (count / 5).ceil();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        // ── Grid ────────────────────────────────────────────────────────────
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white12,
            strokeWidth: 1,
          ),
        ),
        // ── Axes ────────────────────────────────────────────────────────────
        titlesData: FlTitlesData(
          // FIX: reservedSize was 28 — labels like "100" need at least 44px.
          //      No interval set — fl_chart auto-picked ugly values.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 25,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}%',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: step.toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= pp.log.length) {
                  return const SizedBox.shrink();
                }
                // Show only every `step` label to avoid crowding
                if (idx % step != 0) return const SizedBox.shrink();
                final date = pp.log[idx]['log_date'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDate(date),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        // ── Line ────────────────────────────────────────────────────────────
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF00CEC9),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: spot.y == 100
                    ? const Color(0xFF00CEC9)
                    : spot.y == 0
                    ? Colors.redAccent
                    : Colors.orangeAccent,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00CEC9).withOpacity(0.12),
            ),
          ),
        ],
        // ── Tooltip ─────────────────────────────────────────────────────────
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx  = spot.spotIndex;
                final date = idx < pp.log.length
                    ? (pp.log[idx]['log_date'] as String? ?? '')
                    : '';
                return LineTooltipItem(
                  '${_shortDate(date)}\n${spot.y.toStringAsFixed(0)}%',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static String _shortDate(String iso) {
    // '2026-05-27' → 'May 27'
    try {
      final d = DateTime.parse(iso);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month]} ${d.day}';
    } catch (_) {
      return iso;
    }
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[d.weekday]}  ${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Stat Card widget ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}