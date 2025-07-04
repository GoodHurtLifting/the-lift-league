import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/notifications_service.dart';
import 'package:sqflite/sqflite.dart';

class EfficiencyMeter extends StatefulWidget {
  final String userId;
  final String blockId;
  const EfficiencyMeter({super.key, required this.userId, required this.blockId});

  @override
  State<EfficiencyMeter> createState() => _EfficiencyMeterState();
}

class _EfficiencyMeterState extends State<EfficiencyMeter> {
  bool _notified = false;

  late final StreamController<Map<String, dynamic>> _statsController;
  Timer? _timer;

  Stream<Map<String, dynamic>> get _statsStream => _statsController.stream;

  @override
  void initState() {
    super.initState();
    _statsController = StreamController<Map<String, dynamic>>();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final data = await _calculateEfficiency();
      if (!_statsController.isClosed) {
        _statsController.add(data);
      }
    });
    _calculateEfficiency().then((data) {
      if (!_statsController.isClosed) {
        _statsController.add(data);
      }
    });
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

  Future<Map<String, dynamic>> _fetchWeekStats(
      Database db, int blockInstanceId, int week) async {
    final totalRes = await db.rawQuery('''
      SELECT COUNT(*) as c
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND lt.userId = ?
    ''', [blockInstanceId, week, widget.userId]);

    final completedRes = await db.rawQuery('''
      SELECT COUNT(*) as c
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND lt.userId = ? AND lt.liftReps > 0
    ''', [blockInstanceId, week, widget.userId]);

    final avgLiftRes = await db.rawQuery('''
      SELECT AVG(lt.liftScore) as s
      FROM lift_totals lt
      JOIN workout_instances wi ON lt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ?
        AND wi.week = ?
        AND lt.userId = ?
        AND lt.liftReps > 0
    ''', [blockInstanceId, week, widget.userId]);

    final avgWorkoutRes = await db.rawQuery('''
      SELECT AVG(wt.workoutScore) as s
      FROM workout_totals wt
      JOIN workout_instances wi ON wt.workoutInstanceId = wi.workoutInstanceId
      WHERE wi.blockInstanceId = ? AND wi.week = ? AND wt.userId = ?
    ''', [blockInstanceId, week, widget.userId]);

    final total = (totalRes.first['c'] as int?) ?? 0;
    final completed = (completedRes.first['c'] as int?) ?? 0;
    final avgLift = (avgLiftRes.first['s'] as num?)?.toDouble() ?? 0.0;
    final avgWorkout = (avgWorkoutRes.first['s'] as num?)?.toDouble() ?? 0.0;

    return {
      'progress': total == 0 ? 0.0 : completed / total,
      'avgLift': avgLift,
      'avgWorkout': avgWorkout,
    };
  }

  Future<Map<String, dynamic>> _calculateEfficiency() async {
    final db = await DBService().database;
    final blockInstanceId = int.tryParse(widget.blockId) ?? 0;
    final currentWeek = await _currentWeek(db, blockInstanceId);
    final currentStats =
    await _fetchWeekStats(db, blockInstanceId, currentWeek);
    final prevStats = await _fetchWeekStats(db, blockInstanceId, currentWeek - 1);

    final progress = currentStats['progress'] as double;
    final avgLift = currentStats['avgLift'] as double;
    final avgWorkout = currentStats['avgWorkout'] as double;
    final prevLift = prevStats['avgLift'] as double;
    final prevWorkout = prevStats['avgWorkout'] as double;

    int trend = 0; // 1 up, -1 down, 0 flat
    if (avgLift > prevLift || avgWorkout > prevWorkout) {
      trend = 1;
    } else if (avgLift < prevLift && avgWorkout < prevWorkout) {
      trend = -1;
    }

    final efficient =
        progress >= 1.0 && (avgLift > prevLift || avgWorkout > prevWorkout);

    if (efficient && !_notified) {
      NotificationService().showSimpleNotification(
        'Great work!',
        'Efficiency improved this week!',
      );
      _notified = true;
    } else if (!efficient) {
      _notified = false;
    }

    return {
      'progress': progress,
      'avgLift': avgLift,
      'avgWorkout': avgWorkout,
      'trend': trend,
    };
  }

  Icon _trendIcon(int trend) {
    switch (trend) {
      case 1:
        return const Icon(Icons.arrow_upward, color: Colors.green, size: 16);
      case -1:
        return const Icon(Icons.arrow_downward, color: Colors.red, size: 16);
      default:
        return const Icon(Icons.remove, color: Colors.grey, size: 16);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _statsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final progress = data['progress'] as double;
        final avgLift = data['avgLift'] as double;
        final avgWorkout = data['avgWorkout'] as double;
        final trend = data['trend'] as int;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Avg lift: ${avgLift.toStringAsFixed(1)}, ' 'workout: ${avgWorkout.toStringAsFixed(1)}',
                ),
                const SizedBox(width: 6),
                _trendIcon(trend),
              ],
            ),
          ],
        );
      },
    );
  }
}