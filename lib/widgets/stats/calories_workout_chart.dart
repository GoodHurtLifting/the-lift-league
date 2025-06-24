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
    final List<double> workoutIndices = List<double>.from(data['workouts'] ?? []);
    final List<FlSpot> workoutSpots = workoutIndices.map((x) => FlSpot(x, 1)).toList();
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
        if (workoutSpots.isNotEmpty)
          LineChartBarData(
            spots: workoutSpots,
            isCurved: false,
            color: Colors.orange,
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 6,
                    color: Colors.orange,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  ),
            ),
            belowBarData: BarAreaData(show: false),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        }
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
