import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

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
    final xMin = allX.isNotEmpty ? allX.reduce(min) : 0;
    final xMax = allX.isNotEmpty ? allX.reduce(max) : 1;

    // --- 1. Add padding to min/max values ---
    double weightMin = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(min)
        : 0;
    double weightMax = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(max)
        : 1;
    double weightPad = (weightMax - weightMin) * 0.1; // 10% padding
    if (weightMax == weightMin) weightMax += 1;
    weightMin -= weightPad;
    weightMax += weightPad;

    final otherValues = [
      ...bodyFat.map((e) => e.y),
      ...bmi.map((e) => e.y),
    ];
    double otherMin = otherValues.isNotEmpty ? otherValues.reduce(min) : 0;
    double otherMax = otherValues.isNotEmpty ? otherValues.reduce(max) : 1;
    double otherPad = (otherMax - otherMin) * 0.1;
    if (otherMax == otherMin) otherMax += 1;
    otherMin -= otherPad;
    otherMax += otherPad;

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

    SideTitles dateTitles() {
      return SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: ((xMax - xMin) / 4).clamp(1, double.infinity), // About 4 ticks
        getTitlesWidget: (value, meta) {
          final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
          final str = "${date.month.toString().padLeft(2, '0')}/"
              "${date.day.toString().padLeft(2, '0')}/"
              "${date.year.toString().substring(2)}";
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Transform.rotate(
              angle: -0.6, // diagonal
              child: Text(str, style: const TextStyle(fontSize: 10)),
            ),
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
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(right: 4),
            child: RotatedBox(
                quarterTurns: -1,
                child: Text('Weight (lbs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          axisNameSize: 24,
        ),
        rightTitles: AxisTitles(
          sideTitles: makeTitles(otherMin, otherRange, 'Body Fat % / BMI'),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: RotatedBox(
                quarterTurns: -1,
                child: Text('Body Fat % / BMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          axisNameSize: 28,
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: dateTitles()), // <-- USE YOUR FUNCTION HERE!
      ),

      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
    );
  }

  Future<Map<String, List<FlSpot>>> _fetchData() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .where('type', isEqualTo: 'checkin')
        .orderBy('timestamp')
        .get();

    final weight = <FlSpot>[];
    final bodyFat = <FlSpot>[];
    final bmi = <FlSpot>[];
    int i = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final w = (data['weight'] as num?)?.toDouble();
      final bf = (data['bodyFat'] as num?)?.toDouble();
      final b = (data['bmi'] as num?)?.toDouble();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final x = ts.millisecondsSinceEpoch.toDouble();
      if (w != null) weight.add(FlSpot(x, w.toDouble()));
      if (bf != null) bodyFat.add(FlSpot(x, bf.toDouble()));
      if (b != null) bmi.add(FlSpot(x, b.toDouble()));
    }
    return {'weight': weight, 'bodyFat': bodyFat, 'bmi': bmi};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<FlSpot>>>(
      future: _fetchData(),
      builder: (context, snapshot) {
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
            const SizedBox(height: 8),

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

            const SizedBox(height: 8),
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