import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

enum GraphType { dualAxis, unified }

class CheckInGraph extends StatefulWidget {
  final String userId;
  const CheckInGraph({super.key, required this.userId});

  @override
  State<CheckInGraph> createState() => _CheckInGraphState();
}

class _CheckInGraphState extends State<CheckInGraph> {
  GraphType _graphType = GraphType.dualAxis;

  LineChartData _buildDualAxisChart(Map<String, List<FlSpot>> data) {
    final weight = data['weight']!;
    final bodyFat = data['bodyFat']!;
    final bmi = data['bmi']!;

    double weightMin = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(min)
        : 0;
    double weightMax = weight.isNotEmpty
        ? weight.map((e) => e.y).reduce(max)
        : 1;
    if (weightMax == weightMin) weightMax += 1;

    final otherValues = [
      ...bodyFat.map((e) => e.y),
      ...bmi.map((e) => e.y),
    ];
    double otherMin = otherValues.isNotEmpty ? otherValues.reduce(min) : 0;
    double otherMax = otherValues.isNotEmpty ? otherValues.reduce(max) : 1;
    if (otherMax == otherMin) otherMax += 1;

    double weightRange = weightMax - weightMin;
    double otherRange = otherMax - otherMin;

    List<FlSpot> _norm(List<FlSpot> spots, double minVal, double range) {
      return spots
          .map((s) => FlSpot(s.x, (s.y - minVal) / range))
          .toList();
    }

    final weightNorm = _norm(weight, weightMin, weightRange);
    final bodyFatNorm = _norm(bodyFat, otherMin, otherRange);
    final bmiNorm = _norm(bmi, otherMin, otherRange);

    SideTitles makeTitles(double minVal, double range) {
      return SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: 0.25,
        getTitlesWidget: (value, meta) {
          final real = minVal + value * range;
          return Text(real.toStringAsFixed(0),
              style: const TextStyle(fontSize: 10));
        },
      );
    }

    return LineChartData(
      minY: 0,
      maxY: 1,
      lineBarsData: [
        if (weightNorm.isNotEmpty)
          LineChartBarData(
            spots: weightNorm,
            isCurved: false,
            color: Colors.redAccent,
            dotData: FlDotData(show: false),
          ),
        if (bodyFatNorm.isNotEmpty)
          LineChartBarData(
            spots: bodyFatNorm,
            isCurved: false,
            color: Colors.blueAccent,
            dotData: FlDotData(show: false),
          ),
        if (bmiNorm.isNotEmpty)
          LineChartBarData(
            spots: bmiNorm,
            isCurved: false,
            color: Colors.green,
            dotData: FlDotData(show: false),
          ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: makeTitles(weightMin, weightRange)),
        rightTitles: AxisTitles(sideTitles: makeTitles(otherMin, otherRange)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
    );
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0; // or whatever default you want
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _std(List<double> values, double mean) {
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  LineChartData _buildUnifiedChart(Map<String, List<FlSpot>> data) {
    Map<String, List<double>> raw = {
      for (var key in data.keys) key: data[key]!.map((e) => e.y).toList(),
    };

    Map<String, double> means = {
      for (var key in raw.keys) key: _mean(raw[key]!)
    };
    Map<String, double> stds = {
      for (var key in raw.keys)
        key: max(0.0001, _std(raw[key]!, means[key]!))
    };

    Map<String, List<FlSpot>> zSpots = {};
    for (var key in data.keys) {
      zSpots[key] = [
        for (var s in data[key]!)
          FlSpot(s.x, (s.y - means[key]!) / stds[key]!)
      ];
    }

    final allValues = zSpots.values.expand((l) => l.map((e) => e.y));
    double minY = allValues.isNotEmpty ? allValues.reduce(min) : -1;
    double maxY = allValues.isNotEmpty ? allValues.reduce(max) : 1;
    if (minY == maxY) {
      maxY = minY + 1;
    }

    return LineChartData(
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        if (zSpots['weight']!.isNotEmpty)
          LineChartBarData(
            spots: zSpots['weight']!,
            isCurved: false,
            color: Colors.redAccent,
            dotData: FlDotData(show: false),
          ),
        if (zSpots['bodyFat']!.isNotEmpty)
          LineChartBarData(
            spots: zSpots['bodyFat']!,
            isCurved: false,
            color: Colors.blueAccent,
            dotData: FlDotData(show: false),
          ),
        if (zSpots['bmi']!.isNotEmpty)
          LineChartBarData(
            spots: zSpots['bmi']!,
            isCurved: false,
            color: Colors.green,
            dotData: FlDotData(show: false),
          ),
      ],
      titlesData: const FlTitlesData(),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
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
      if (w != null) weight.add(FlSpot(i.toDouble(), w));
      if (bf != null) bodyFat.add(FlSpot(i.toDouble(), bf));
      if (b != null) bmi.add(FlSpot(i.toDouble(), b));
      i++;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _graphType = GraphType.dualAxis);
                  },
                  child: Text(
                    'Dual Axis',
                    style: TextStyle(
                      fontWeight: _graphType == GraphType.dualAxis
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _graphType = GraphType.unified);
                  },
                  child: Text(
                    'Unified',
                    style: TextStyle(
                      fontWeight: _graphType == GraphType.unified
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: LineChart(
                  _graphType == GraphType.dualAxis
                      ? _buildDualAxisChart(data)
                      : _buildUnifiedChart(data),
                  key: ValueKey(_graphType), // this triggers animation on graph type change
                  // swapAnimationDuration: const Duration(milliseconds: 500), // REMOVE THIS LINE
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