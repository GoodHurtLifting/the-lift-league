import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../services/db_service.dart';

class CaloriesWorkoutChart extends StatefulWidget {
  final String userId;
  const CaloriesWorkoutChart({super.key, required this.userId});

  @override
  State<CaloriesWorkoutChart> createState() => _CaloriesWorkoutChartState();
}

class _CaloriesWorkoutChartState extends State<CaloriesWorkoutChart> {
  Future<Map<String, dynamic>> _fetchData() async {
    final db = await DBService().database;
    final energyRows = await db.rawQuery('''
      SELECT date(date) as d, SUM(kcalIn) as inCals, SUM(kcalOut) as outCals
      FROM health_energy_samples
      GROUP BY d
      ORDER BY d
    ''');

    final workoutRows = await db.rawQuery('''
      SELECT date(wi.startTime) as d
      FROM workout_totals wt
      JOIN workout_instances wi ON wt.workoutInstanceId = wi.workoutInstanceId
      WHERE wt.userId = ?
      GROUP BY d
      ORDER BY d
    ''', [widget.userId]);

    final dates = <DateTime>{};
    for (final row in energyRows) {
      final s = row['d'] as String?;
      if (s != null) dates.add(DateTime.parse(s));
    }
    for (final row in workoutRows) {
      final s = row['d'] as String?;
      if (s != null) dates.add(DateTime.parse(s));
    }
    final sorted = dates.toList()..sort();
    final dateToIndex = <String, int>{};
    for (var i = 0; i < sorted.length; i++) {
      dateToIndex[sorted[i].toIso8601String().split('T')[0]] = i;
    }

    final inSpots = <FlSpot>[];
    final outSpots = <FlSpot>[];
    for (final row in energyRows) {
      final s = row['d'] as String?;
      if (s == null) continue;
      final idx = dateToIndex[s]?.toDouble() ?? 0;
      final inVal = (row['inCals'] as num?)?.toDouble() ?? 0;
      final outVal = (row['outCals'] as num?)?.toDouble() ?? 0;
      inSpots.add(FlSpot(idx, inVal));
      outSpots.add(FlSpot(idx, outVal));
    }

    final workoutIndices = <double>[];
    for (final row in workoutRows) {
      final s = row['d'] as String?;
      if (s == null) continue;
      final idx = dateToIndex[s];
      if (idx != null) workoutIndices.add(idx.toDouble());
    }

    return {
      'dates': sorted,
      'in': inSpots,
      'out': outSpots,
      'workouts': workoutIndices,
    };
  }

  LineChartData _buildChart(Map<String, dynamic> data) {
    final List<FlSpot> inSpots = List<FlSpot>.from(data['in']);
    final List<FlSpot> outSpots = List<FlSpot>.from(data['out']);
    final dates = data['dates'] as List<DateTime>;

    final xMax = dates.isNotEmpty ? dates.length - 1.0 : 1.0;

    double inMin = inSpots.isNotEmpty
        ? inSpots.map((e) => e.y).reduce(min)
        : 0;
    double inMax = inSpots.isNotEmpty
        ? inSpots.map((e) => e.y).reduce(max)
        : 1;
    if (inMax - inMin < 500) inMax = inMin + 500;

    double outMin = outSpots.isNotEmpty
        ? outSpots.map((e) => e.y).reduce(min)
        : 0;
    double outMax = outSpots.isNotEmpty
        ? outSpots.map((e) => e.y).reduce(max)
        : 1;
    if (outMax - outMin < 500) outMax = outMin + 500;

    double inRange = inMax - inMin;
    double outRange = outMax - outMin;

    List<FlSpot> norm(List<FlSpot> list, double minVal, double range) {
      return list
          .map((s) => FlSpot(s.x, (s.y - minVal) / range))
          .toList();
    }

    final inNorm = norm(inSpots, inMin, inRange);
    final outNorm = norm(outSpots, outMin, outRange);

    SideTitles makeTitles(double minVal, double range) {
      return SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) {
          final real = (minVal + value * range).round();
          return Text(real.toString(), style: const TextStyle(fontSize: 10));
        },
      );
    }

    return LineChartData(
      minX: 0,
      maxX: xMax,
      minY: 0,
      maxY: 1,
      lineBarsData: [
        if (inNorm.isNotEmpty)
          LineChartBarData(
            spots: inNorm,
            isCurved: false,
            color: Colors.green,
            dotData: FlDotData(show: false),
            barWidth: 2,
          ),
        if (outNorm.isNotEmpty)
          LineChartBarData(
            spots: outNorm,
            isCurved: false,
            color: Colors.redAccent,
            dotData: FlDotData(show: false),
            barWidth: 2,
          ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: makeTitles(inMin, inRange)),
        rightTitles: AxisTitles(sideTitles: makeTitles(outMin, outRange)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= dates.length) {
                return const SizedBox.shrink();
              }
              final d = dates[index];
              return Text('${d.month}/${d.day}',
                  style: const TextStyle(fontSize: 10));
            },
          ),
        ),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
      lineTouchData: const LineTouchData(enabled: false),
    );
  }

  ScatterChartData _buildScatter(Map<String, dynamic> data) {
    final List<double> workoutIdx = List<double>.from(data['workouts']);
    final dates = data['dates'] as List<DateTime>;
    final xMax = dates.isNotEmpty ? dates.length - 1.0 : 1.0;
    final scatterSpots = workoutIdx
        .map((x) => ScatterSpot(x, 1,
            color: Colors.orange, radius: 4))
        .toList();
    return ScatterChartData(
      scatterSpots: scatterSpots,
      minX: 0,
      maxX: xMax,
      minY: 0,
      maxY: 1,
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      scatterTouchData: const ScatterTouchData(enabled: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if ((data['in'] as List).isEmpty && (data['out'] as List).isEmpty) {
          return const Text('No calorie data yet.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calories vs Workouts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  LineChart(_buildChart(data)),
                  ScatterChart(_buildScatter(data)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
