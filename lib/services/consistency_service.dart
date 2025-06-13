import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/notifications_service.dart';

class ConsistencyService {
  final DBService _db = DBService();
  final NotificationService _notifier = NotificationService();

  Future<Map<int, Map<String, int>>> _fetchWeeklyCounts(
      String userId, int blockInstanceId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT week,
             COUNT(*) as scheduled,
             SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as completed
        FROM workout_instances
       WHERE userId = ? AND blockInstanceId = ?
    GROUP BY week
    ORDER BY week
    ''', [userId, blockInstanceId]);

    final Map<int, Map<String, int>> data = {};
    for (final row in result) {
      final week = row['week'] as int? ?? 0;
      data[week] = {
        'scheduled': (row['scheduled'] as int? ?? 0),
        'completed': (row['completed'] as int? ?? 0),
      };
    }
    return data;
  }

  Future<Map<String, dynamic>> getWeeklyConsistency({
    required String userId,
    required int blockInstanceId,
  }) async {
    final weeks = await _fetchWeeklyCounts(userId, blockInstanceId);
    if (weeks.isEmpty) {
      return {
        'currentWeek': 1,
        'scheduled': 0,
        'completed': 0,
        'percentage': 0.0,
        'streak': 0,
      };
    }

    final sortedWeeks = weeks.keys.toList()..sort();
    int currentWeek = sortedWeeks.first;
    for (final w in sortedWeeks) {
      final counts = weeks[w]!;
      currentWeek = w;
      if (counts['completed']! < counts['scheduled']!) {
        break;
      }
    }

    int streak = 0;
    for (int w = currentWeek; w >= sortedWeeks.first; w--) {
      final counts = weeks[w];
      if (counts != null && counts['scheduled'] == counts['completed'] &&
          counts['scheduled']! > 0) {
        streak++;
      } else {
        break;
      }
    }

    final scheduled = weeks[currentWeek]?['scheduled'] ?? 0;
    final completed = weeks[currentWeek]?['completed'] ?? 0;
    final percent = scheduled > 0 ? (completed / scheduled) * 100.0 : 0.0;

    return {
      'currentWeek': currentWeek,
      'scheduled': scheduled,
      'completed': completed,
      'percentage': percent,
      'streak': streak,
    };
  }

  Future<void> checkWeekCompletionAndNotify({
    required String userId,
    required int blockInstanceId,
  }) async {
    final data = await getWeeklyConsistency(
      userId: userId,
      blockInstanceId: blockInstanceId,
    );

    final scheduled = data['scheduled'] as int;
    final completed = data['completed'] as int;
    final currentWeek = data['currentWeek'] as int;

    if (scheduled > 0 && scheduled == completed) {
      _notifier.showSimpleNotification(
        'Great job!',
        'You completed all $scheduled workouts for week $currentWeek!',
      );
    }
  }
}