import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/db_service.dart';

class BodyWeightChart extends StatefulWidget {
  final String userId;
  const BodyWeightChart({super.key, required this.userId});

  @override
  State<BodyWeightChart> createState() => _BodyWeightChartState();
}

class _BodyWeightChartState extends State<BodyWeightChart> {
  Future<Map<String, dynamic>> _fetchData() async {
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

    final dates = <DateTime>[];
    final weight = <FlSpot>[];
    final bodyFat = <FlSpot>[];
    final bmi = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final dateStr = row['d'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      dates.add(date);
      final x = i.toDouble();
      final w = (row['weight'] as num?)?.toDouble();
      final bf = (row['bodyFat'] as num?)?.toDouble();
      final b = (row['bmi'] as num?)?.toDouble();
      if (w != null) weight.add(FlSpot(x, w));
      if (bf != null) bodyFat.add(FlSpot(x, bf));
      if (b != null) bmi.add(FlSpot(x, b));
    }
    return {
      'dates': dates,
      'weight': weight,
      'bodyFat': bodyFat,
      'bmi': bmi,
    };
  }

  LineChartData _buildChart(Map<String, dynamic> data) {
    final weight = List<FlSpot>.from(data['weight']);
    final bodyFat = List<FlSpot>.from(data['bodyFat']);
    final bmi = List<FlSpot>.from(data['bmi']);
    final dates = List<DateTime>.from(data['dates']);

    final xMax = dates.isNotEmpty ? dates.length - 1.0 : 1.0;

    double weightMin =
        weight.isNotEmpty ? weight.map((e) => e.y).reduce((a, b) => a < b ? a : b) : 0;
    double weightMax =
        weight.isNotEmpty ? weight.map((e) => e.y).reduce((a, b) => a > b ? a : b) : 1;
    if (weightMax == weightMin) weightMax = weightMin + 1;
    weightMin -= 8;
    weightMax += 8;

    final otherValues = [
      ...bodyFat.map((e) => e.y),
      ...bmi.map((e) => e.y),
    ];
    double otherMin = otherValues.isNotEmpty ?
        otherValues.reduce((a, b) => a < b ? a : b) : 0;
    double otherMax = otherValues.isNotEmpty ?
        otherValues.reduce((a, b) => a > b ? a : b) : 1;
    if (otherMax == otherMin) otherMax = otherMin + 1;
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

    SideTitles makeTitles(double minVal, double range) {
      return SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: 0.25,
        getTitlesWidget: (value, meta) {
          final real = minVal + value * range;
          return Text(real.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10));
        },
      );
    }

    return LineChartData(
      minX: 0,
      maxX: xMax,
      minY: 0,
      maxY: 1,
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
        leftTitles: AxisTitles(sideTitles: makeTitles(weightMin, weightRange)),
        rightTitles: AxisTitles(sideTitles: makeTitles(otherMin, otherRange)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= dates.length) {
                return const SizedBox.shrink();
              }
              final d = dates[idx];
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if ((data['weight'] as List).isEmpty &&
            (data['bodyFat'] as List).isEmpty &&
            (data['bmi'] as List).isEmpty) {
          return const Text('No weight data yet.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Body Metrics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(_buildChart(data)),
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
