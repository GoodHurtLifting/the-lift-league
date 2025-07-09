import 'package:collection/collection.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/momentum_service.dart';
import 'package:sqflite/sqflite.dart';

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

/// Details for the efficiency meter UI.
class EfficiencyStats {
  final double progress;   // 0–1 progress for current week
  final double avgLift;    // mean lift score this week
  final double avgWorkout; // mean workout score this week
  final int trend;         // 1 up, -1 down, 0 flat
  final bool efficient;    // improvement achieved this week

  const EfficiencyStats(
    this.progress,
    this.avgLift,
    this.avgWorkout,
    this.trend,
    this.efficient,
  );
}

class _WeekStats {
  final double progress;
  final double avgLift;
  final double avgWorkout;

  const _WeekStats(this.progress, this.avgLift, this.avgWorkout);
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
  final MomentumService _momentum = MomentumService();

  /// 0–100 % based on recent workout history.
  Future<double> momentumPercent({required String userId}) {
    return _momentum.momentumPercent(userId: userId);
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

  // ──────────────────  EFFICIENCY METER DATA  ──────────────────
  Future<EfficiencyStats> efficiencyMeter({
    required String userId,
    required int blockInstanceId,
  }) async {
    final db = await _db.database;

    final currentWeek = await _currentWeek(db, blockInstanceId);
    final current = await _fetchWeekStats(db, blockInstanceId, currentWeek, userId);
    final previous =
        await _fetchWeekStats(db, blockInstanceId, currentWeek - 1, userId);

    int trend = 0; // 1 up, -1 down, 0 flat
    if (current.avgLift > previous.avgLift ||
        current.avgWorkout > previous.avgWorkout) {
      trend = 1;
    } else if (current.avgLift < previous.avgLift &&
        current.avgWorkout < previous.avgWorkout) {
      trend = -1;
    }

    final efficient =
        current.progress >= 1.0 && trend == 1;

    return EfficiencyStats(
      current.progress,
      current.avgLift,
      current.avgWorkout,
      trend,
      efficient,
    );
  }

  Future<int> _currentWeek(Database db, int blockInstanceId) async {
    final startRes = await db.query(
      'block_instances',
      columns: ['startDate'],
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );
    if (startRes.isEmpty || startRes.first['startDate'] == null) {
      return 1;
    }
    final start = DateTime.parse(startRes.first['startDate'] as String);
    final now = DateTime.now();
    final diff = now.difference(start).inDays;
    final week = (diff ~/ 7) + 1;
    final maxRes = await db.rawQuery(
      'SELECT MAX(week) as w FROM workout_instances WHERE blockInstanceId = ?',
      [blockInstanceId],
    );
    final maxWeek = (maxRes.first['w'] as int?) ?? 1;
    return week.clamp(1, maxWeek);
  }

  Future<_WeekStats> _fetchWeekStats(
      Database db, int blockInstanceId, int week, String userId) async {
    final totalRes = await db.rawQuery('''
      SELECT COUNT(*) as c
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND lt.userId = ?
    ''', [blockInstanceId, week, userId]);

    final completedRes = await db.rawQuery('''
      SELECT COUNT(*) as c
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND lt.userId = ? AND lt.liftReps > 0
    ''', [blockInstanceId, week, userId]);

    final avgLiftRes = await db.rawQuery('''
      SELECT AVG(lt.liftScore) as s
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ?
        AND wi.week = ?
        AND lt.userId = ?
        AND lt.liftReps > 0
    ''', [blockInstanceId, week, userId]);

    final avgWorkoutRes = await db.rawQuery('''
      SELECT AVG(wt.workoutScore) as s
      FROM workout_totals wt
      JOIN workout_instances wi ON wt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND wt.userId = ?
    ''', [blockInstanceId, week, userId]);

    final total = (totalRes.first['c'] as int?) ?? 0;
    final completed = (completedRes.first['c'] as int?) ?? 0;
    final avgLift = (avgLiftRes.first['s'] as num?)?.toDouble() ?? 0.0;
    final avgWorkout = (avgWorkoutRes.first['s'] as num?)?.toDouble() ?? 0.0;

    final progress = total == 0 ? 0.0 : completed / total;

    return _WeekStats(progress, avgLift, avgWorkout);
  }
}
