import 'db_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserStatsService {
  final DBService _dbService = DBService();

  Future<String> getBlockName(int blockInstanceId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT b.blockName
      FROM block_instances bi
      JOIN blocks b ON bi.blockId = b.blockId
      WHERE bi.blockInstanceId = ?
    ''', [blockInstanceId]);

    return result.isNotEmpty ? result.first['blockName'] as String : 'Block';
  }

  Future<double> getBlockWorkload(int blockInstanceId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT SUM(workoutWorkload) as totalWorkload
      FROM workout_totals wt
      JOIN workout_instances wi ON wt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ?
    ''', [blockInstanceId]);

    return (result.first['totalWorkload'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getCompletedWorkoutCount(int blockInstanceId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as completedCount
      FROM workout_instances
      WHERE blockInstanceId = ? AND completed = 1
    ''', [blockInstanceId]);

    return result.first['completedCount'] as int? ?? 0;
  }

  Future<int> getDaysTakenForBlock(int blockInstanceId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT 
        MIN(startTime) as firstWorkout,
        MAX(endTime) as lastWorkout
      FROM workout_instances
      WHERE blockInstanceId = ? AND completed = 1
    ''', [blockInstanceId]);

    final start = result.first['firstWorkout'] as String?;
    final end = result.first['lastWorkout'] as String?;

    if (start == null || end == null) return 0;

    final startDate = DateTime.parse(start);
    final endDate = DateTime.parse(end);

    return endDate.difference(startDate).inDays + 1;
  }

  Future<int> getCalendarDaysForBlock(int blockInstanceId) async {
    final db = await _dbService.database;

    final result = await db.rawQuery('''
    SELECT MIN(startTime) as firstWorkout, MAX(endTime) as lastWorkout
    FROM workout_instances
    WHERE blockInstanceId = ? AND completed = 1
  ''', [blockInstanceId]);

    if (result.isEmpty || result.first['firstWorkout'] == null || result.first['lastWorkout'] == null) {
      return 0;
    }

    final first = DateTime.parse(result.first['firstWorkout'] as String);
    final last = DateTime.parse(result.first['lastWorkout'] as String);

    return last.difference(first).inDays + 1; // +1 to count both first and last day
  }


  Future<List<Map<String, dynamic>>> getBlockEarnedBadges(String userId, int blockInstanceId) async {
    final db = await _dbService.database;
    return await db.rawQuery('''
      SELECT badgeId, name, imagePath
      FROM earned_badges
      WHERE userId = ? AND blockInstanceId = ?
    ''', [userId, blockInstanceId]);
  }

  Future<double> getTotalLbsLifted(String userId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
    SELECT SUM(liftWorkload) as totalLbs 
    FROM lift_totals 
    WHERE userId = ?
  ''', [userId]);


    return (result.first['totalLbs'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTotalCompletedBlocks(String userId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
    SELECT COUNT(DISTINCT blockInstanceId) as totalBlocks
    FROM block_instances
    WHERE userId = ? AND endDate IS NOT NULL
  ''', [userId]);

    return (result.first['totalBlocks'] as int?) ?? 0;
  }

  Future<Map<String, double>> getBigThreePRsForBlock(
      String userId, int blockInstanceId) async {
    final db = await _dbService.database;
    final result = await db.query('block_instances',
        columns: ['startDate', 'endDate'],
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
        limit: 1);

    if (result.isEmpty) return {};
    final startStr = result.first['startDate'] as String?;
    if (startStr == null) return {};
    final endStr = result.first['endDate'] as String?;

    final start = DateTime.parse(startStr);
    final end = endStr != null ? DateTime.parse(endStr) : DateTime.now();

    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries')
        .where('timestamp', isGreaterThanOrEqualTo: startTs)
        .where('timestamp', isLessThanOrEqualTo: endTs)
        .where('type', isEqualTo: 'clink')
        .get();

    final prs = <String, double>{};
    final regex =
    RegExp(r'New (Bench Press|Squats|Deadlift) PR - (\d+(?:\.\d+)?)');

    for (final doc in snapshot.docs) {
      final clink = doc.data()['clink'] as String? ?? '';
      final match = regex.firstMatch(clink);
      if (match != null) {
        final lift = match.group(1)!;
        final weight = double.tryParse(match.group(2)!) ?? 0.0;
        final current = prs[lift] ?? 0.0;
        if (weight > current) {
          prs[lift] = weight;
        }
      }
    }

    return prs;
  }
}
