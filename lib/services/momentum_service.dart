import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/notifications_service.dart';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

class MomentumService {
  final DBService _db = DBService();
  final NotificationService _notifier = NotificationService();

  Future<Map<String, dynamic>> calculateMomentum({
    required String userId,
    double dropPerMissedDay = 0.02,
    int lookbackDays = 14,
  }) async {
    final db = await _db.database;

    final workouts = await db.rawQuery('''
      SELECT endTime, week, blockInstanceId
      FROM workout_instances
      WHERE userId = ? AND completed = 1 AND endTime IS NOT NULL
      ORDER BY endTime ASC
    ''', [userId]);

    final Map<DateTime, Map<String, dynamic>> workoutsByDay = {};
    for (final row in workouts) {
      final end = DateTime.parse(row['endTime'] as String);
      final day = DateTime(end.year, end.month, end.day);
      workoutsByDay[day] = {
        'week': row['week'] as int? ?? 1,
        'blockInstanceId': row['blockInstanceId'] as int? ?? 0,
      };
    }

    final blockRows = await db.query('block_instances',
        columns: ['blockInstanceId'], where: 'userId = ?', whereArgs: [userId]);
    double lifetimeTotal = 0.0;
    int lifetimeWeeks = 0;

    for (final b in blockRows) {
      final id = b['blockInstanceId'] as int;
      final maxRes = await db.rawQuery(
          'SELECT MAX(week) as w FROM workout_instances WHERE blockInstanceId = ?',
          [id]);
      final maxWeek = maxRes.first['w'] as int? ?? 0;
      for (int w = 1; w <= maxWeek; w++) {
        final stats = await _weekStats(db, id, w, userId);
        if (stats['total'] > 0) {
          lifetimeTotal += (stats['consistency'] + stats['efficiency']) / 2.0;
          lifetimeWeeks++;
        }
      }
    }

    final lifetimeAvg =
    lifetimeWeeks > 0 ? lifetimeTotal / lifetimeWeeks : 0.0;

    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays - 1));

    double momentum = lifetimeAvg;
    bool declining = false;
    final trend = <double>[];
    final drops = <bool>[];
    bool increased = false;

    for (int i = 0; i < lookbackDays; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (workoutsByDay.containsKey(day)) {
        final info = workoutsByDay[day]!;
        final stats = await _weekStats(
            db, info['blockInstanceId'] as int, info['week'] as int, userId);
        momentum =
            ((stats['consistency'] + stats['efficiency']) / 2.0).clamp(0.0, 100.0);
        if (declining && momentum > (trend.isNotEmpty ? trend.last : 0)) {
          increased = true;
        }
        declining = false;
        drops.add(false);
      } else {
        momentum = max(0, momentum - dropPerMissedDay * 100);
        declining = true;
        drops.add(true);
      }
      trend.add(double.parse(momentum.toStringAsFixed(1)));
    }

    if (increased) {
      _notifier.showSimpleNotification(
          'Momentum Rising', 'Great job getting back on track!');
    }

    return {
      'trend': trend,
      'drops': drops,
      'current': trend.isNotEmpty ? trend.last : 0.0,
      'average': lifetimeAvg,
    };
  }

  Future<Map<String, dynamic>> _weekStats(
      DatabaseExecutor db, int blockInstanceId, int week, String userId) async {
    final totalRaw = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM workout_instances
      WHERE blockInstanceId = ? AND week = ?
    ''', [blockInstanceId, week]);
    final total = totalRaw.first['total'] as int? ?? 0;

    final completedRaw = await db.rawQuery('''
      SELECT COUNT(*) as completed
      FROM workout_instances
      WHERE blockInstanceId = ? AND week = ? AND completed = 1
    ''', [blockInstanceId, week]);
    final completed = completedRaw.first['completed'] as int? ?? 0;
    final consistency = total > 0 ? (completed / total) * 100 : 0.0;

    final currentScoreRaw = await db.rawQuery('''
      SELECT AVG(workoutScore) as avgScore
      FROM workout_totals
      WHERE blockInstanceId = ? AND workoutInstanceId IN (
        SELECT workoutInstanceId FROM workout_instances
        WHERE blockInstanceId = ? AND week = ? AND completed = 1
      )
    ''', [blockInstanceId, blockInstanceId, week]);
    final currentAvg =
        (currentScoreRaw.first['avgScore'] as num?)?.toDouble() ?? 0.0;

    final prevScoreRaw = await db.rawQuery('''
      SELECT AVG(workoutScore) as avgScore
      FROM workout_totals
      WHERE blockInstanceId = ? AND workoutInstanceId IN (
        SELECT workoutInstanceId FROM workout_instances
        WHERE blockInstanceId = ? AND week < ? AND completed = 1
      )
    ''', [blockInstanceId, blockInstanceId, week]);
    final prevAvg = (prevScoreRaw.first['avgScore'] as num?)?.toDouble() ?? 0.0;

    double efficiency;
    if (prevAvg == 0) {
      efficiency = currentAvg > 0 ? 100.0 : 0.0;
    } else {
      efficiency = (currentAvg / prevAvg) * 100;
    }

    return {
      'total': total,
      'consistency': double.parse(consistency.toStringAsFixed(1)),
      'efficiency': double.parse(efficiency.toStringAsFixed(1)),
    };
  }
}