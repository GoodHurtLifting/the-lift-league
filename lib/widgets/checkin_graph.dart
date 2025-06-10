import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CheckInGraph extends StatelessWidget {
  final String userId;
  const CheckInGraph({super.key, required this.userId});

  Future<Map<String, List<FlSpot>>> _fetchData() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
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
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    if (data['weight']!.isNotEmpty)
                      LineChartBarData(
                        spots: data['weight']!,
                        isCurved: false,
                        color: Colors.redAccent,
                        dotData: FlDotData(show: false),
                      ),
                    if (data['bodyFat']!.isNotEmpty)
                      LineChartBarData(
                        spots: data['bodyFat']!,
                        isCurved: false,
                        color: Colors.blueAccent,
                        dotData: FlDotData(show: false),
                      ),
                    if (data['bmi']!.isNotEmpty)
                      LineChartBarData(
                        spots: data['bmi']!,
                        isCurved: false,
                        color: Colors.green,
                        dotData: FlDotData(show: false),
                      ),
                  ],
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
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