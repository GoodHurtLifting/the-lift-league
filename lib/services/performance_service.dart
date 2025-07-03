import 'package:collection/collection.dart';
import 'package:lift_league/services/db_service.dart';

/// ─────────────────────────────────────────────────────────
/// 📊  Value Objects
/// ─────────────────────────────────────────────────────────
class WeeklySummary {
  final int week;
  final int scheduled;
  final int completed;
  const WeeklySummary(this.week, this.scheduled, this.completed);
  double get percent => scheduled == 0 ? 0 : completed / scheduled * 100;
}

class ConsistencySummary {
  final int currentWeek;   // 1–4
  final double percent;    // 0,25,50,75,100
  const ConsistencySummary(this.currentWeek, this.percent);
}

class EfficiencySummary {
  final double avgLift;    // mean of completed lift scores
  final double avgWorkout; // mean of completed workout scores
  const EfficiencySummary(this.avgLift, this.avgWorkout);
}

/// ─────────────────────────────────────────────────────────
/// 🔥  PERFORMANCE SERVICE  (one stop for all three meters)
/// ─────────────────────────────────────────────────────────
class PerformanceService {
  final _db = DBService();

  // ──────────────────  CONSISTENCY  ──────────────────
  /// Returns 0/25/50/75/100 based on “perfect” weeks in the block.
  Future<ConsistencySummary> consistency({
    required String userId,
    required int blockInstanceId,
  }) async {
    final db  = await _db.database;
    final res = await db.rawQuery('''
      SELECT week,
             COUNT(*)                              AS scheduled,
             SUM(CASE WHEN completed = 1 THEN 1 END) AS completed
        FROM workout_instances
       WHERE userId = ? AND blockInstanceId = ?
    GROUP BY week
    HAVING scheduled > 0
    ORDER BY week;
    ''', [userId, blockInstanceId]);

    if (res.isEmpty) return const ConsistencySummary(1, 0);

    final weeks = res
        .map((r) => WeeklySummary(
              r['week'] as int,
              r['scheduled'] as int,
              (r['completed'] as int?) ?? 0,
            ))
        .sortedBy<num>((w) => w.week);

    final currentWeek     = weeks.last.week;
    final completedWeeks  = weeks
        .where((w) => w.completed >= w.scheduled && w.scheduled > 0)
        .length;
    final percent         = completedWeeks * 25.0;

    return ConsistencySummary(currentWeek, percent);
  }

  // ──────────────────  MOMENTUM  ──────────────────
  /// 0–100 % based on days since last completed workout (28-day decay).
  Future<double> momentumPercent({required String userId}) async {
    final db  = await _db.database;
    final res = await db.rawQuery('''
      SELECT MAX(endTime) AS lastCompleted
        FROM workout_instances
       WHERE userId = ? AND completed = 1;
    ''', [userId]);

    final last = res.first['lastCompleted'] as String?;
    if (last == null) return 0;

    final lastDt  = DateTime.parse(last);
    final daysAgo = DateTime.now().difference(lastDt).inDays;
    if (daysAgo >= 28) return 0;

    return ((28 - daysAgo) / 28) * 100;     // linear decay
  }

  // ──────────────────  EFFICIENCY  ──────────────────
  /// Mean lift & workout scores for completed entries in the block.
  Future<EfficiencySummary> efficiency({
    required String userId,
    required int blockInstanceId,
  }) async {
    final db = await _db.database;

    final liftRes = await db.rawQuery('''
      SELECT AVG(liftScore) AS avgLift
        FROM lift_totals lt
        JOIN workout_instances wi
          ON wi.workoutInstanceId = lt.workoutInstanceId
       WHERE wi.blockInstanceId = ? AND wi.userId = ? AND wi.completed = 1;
    ''', [blockInstanceId, userId]);

    final wktRes = await db.rawQuery('''
      SELECT AVG(workoutScore) AS avgWorkout
        FROM workout_totals
       WHERE blockInstanceId = ? AND userId = ?;
    ''', [blockInstanceId, userId]);

    return EfficiencySummary(
      (liftRes.first['avgLift'] as num?)?.toDouble() ?? 0,
      (wktRes.first['avgWorkout'] as num?)?.toDouble() ?? 0,
    );
  }
}
