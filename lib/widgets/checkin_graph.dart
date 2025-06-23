import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import '../services/db_service.dart';

class CheckInGraph extends StatefulWidget {
  final String userId;
  const CheckInGraph({super.key, required this.userId});

  @override
  State<CheckInGraph> createState() => _CheckInGraphState();
}

class _CheckInGraphState extends State<CheckInGraph> {

  LineChartData _buildDualAxisChart(Map<String, List<FlSpot>> data) {
    final weight = data['weight']!;
    final bodyFat = data['bodyFat']!;
    final bmi = data['bmi']!;
    final allX = [...weight, ...bodyFat, ...bmi].map((e) => e.x).toList();
    final xMin = allX.isNotEmpty ? allX.reduce(min) : 0.0;
    final xMax = allX.isNotEmpty ? allX.reduce(max) : 1.0;

    // --- 1. Add padding to min/max values ---
    double weightMin = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(min)
        : 0;
    double weightMax = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(max)
        : 1;

    if (weightMax == weightMin) {
      // Add a dummy range so normalization doesn't divide by zero
      weightMax = weightMin + 1;
    }

    weightMin -= 8;
    weightMax += 8;

// --- Body Fat/BMI ---
    final otherValues = [
      ...bodyFat.map((e) => e.y),
      ...bmi.map((e) => e.y),
    ];
    double otherMin = otherValues.isNotEmpty ? otherValues.reduce(min) : 0;
    double otherMax = otherValues.isNotEmpty ? otherValues.reduce(max) : 1;
    if (otherMax == otherMin) {
      otherMax = otherMin + 1;
    }

    otherMin -= 6;
    otherMax += 6;

    double weightRange = weightMax - weightMin;
    double otherRange = otherMax - otherMin;

    List<FlSpot> norm(List<FlSpot> spots, double minVal, double range) {
      return spots
          .map((s) => FlSpot(s.x, (s.y - minVal) / range))
          .toList();
    }

    final weightNorm = norm(weight, weightMin, weightRange);
    final bodyFatNorm = norm(bodyFat, otherMin, otherRange);
    final bmiNorm = norm(bmi, otherMin, otherRange);

    SideTitles makeTitles(double minVal, double range, String label) {
      return SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: 0.25,
        getTitlesWidget: (value, meta) {
          final real = minVal + value * range;
          return Text(
            real.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10),
          );
        },
      );
    }

    return LineChartData(
      minY: 0,
      maxY: 1,
      minX: xMin,
      maxX: xMax,
      lineBarsData: [
        if (weightNorm.isNotEmpty)
          LineChartBarData(
            spots: weightNorm,
            isCurved: false,
            color: Colors.redAccent,
            dotData: FlDotData(show: false),
            barWidth: 2,
          ),
        if (bodyFatNorm.isNotEmpty)
          LineChartBarData(
            spots: bodyFatNorm,
            isCurved: false,
            color: Colors.blueAccent,
            dotData: FlDotData(show: false),
            barWidth: 2,
          ),
        if (bmiNorm.isNotEmpty)
          LineChartBarData(
            spots: bmiNorm,
            isCurved: false,
            color: Colors.green,
            dotData: FlDotData(show: false),
            barWidth: 2,
          ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: makeTitles(weightMin, weightRange, 'Weight (lbs)'),
        ),
        rightTitles: AxisTitles(
          sideTitles: makeTitles(otherMin, otherRange, 'Body Fat % / BMI'),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),

      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
    );
  }

  Future<Map<String, List<FlSpot>>> _fetchData() async {
    final db = await DBService().database;
    final rows = await db.rawQuery('''
      SELECT date(date) as d,
             AVG(value) as weight,
             AVG(bodyFat) as bodyFat,
             AVG(bmi) as bmi
      FROM health_weight_samples
      GROUP BY d
      ORDER BY d
    ''');

    final weight = <FlSpot>[];
    final bodyFat = <FlSpot>[];
    final bmi = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final w = (row['weight'] as num?)?.toDouble();
      final bf = (row['bodyFat'] as num?)?.toDouble();
      final b = (row['bmi'] as num?)?.toDouble();
      final x = i.toDouble();
      if (w != null) weight.add(FlSpot(x, w));
      if (bf != null) bodyFat.add(FlSpot(x, bf));
      if (b != null) bmi.add(FlSpot(x, b));
    }
    return {'weight': weight, 'bodyFat': bodyFat, 'bmi': bmi};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<FlSpot>>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.values.every((list) => list.isEmpty)) {
          return const Text('No check-in data yet.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Check-In Progress',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),


            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: LineChart(
                    _buildDualAxisChart(data),
                    key: const ValueKey('dualAxis'),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: const [
                _Legend(color: Colors.redAccent, label: 'Weight'),
                SizedBox(width: 12),
                _Legend(color: Colors.blueAccent, label: 'Body Fat%'),
                SizedBox(width: 12),
                _Legend(color: Colors.green, label: 'BMI'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}