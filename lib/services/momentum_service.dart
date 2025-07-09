import 'dart:math';
import 'package:lift_league/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

class MomentumService {
  final _db = DBService();

  Future<double> momentumPercent({required String userId}) async {
    final Database db = await _db.database;

    // Last completed workout
    final lastRes = await db.rawQuery('''
      SELECT MAX(endTime) AS lastCompleted
        FROM workout_instances
       WHERE userId = ? AND completed = 1;
    ''', [userId]);
    final lastStr = lastRes.first['lastCompleted'] as String?;
    if (lastStr == null) return 0;

    final now = DateTime.now();
    final lastDt = DateTime.parse(lastStr);
    final daysAgo = now.difference(lastDt).inDays;

    // Distinct workout days in the last 24 days
    final startWindow = now.subtract(const Duration(days: 24));
    final countRes = await db.rawQuery('''
      SELECT COUNT(DISTINCT DATE(endTime)) AS daysWorked
        FROM workout_instances
       WHERE userId = ? AND completed = 1 AND endTime >= ?;
    ''', [userId, startWindow.toIso8601String()]);
    final daysWorked = (countRes.first['daysWorked'] as int?) ?? 0;

    final increase = (daysWorked / 24) * 100;
    final decrease = (min(daysAgo, 7) / 7) * 100;

    final momentum = increase - decrease;
    return momentum.clamp(0, 100);
  }
}
