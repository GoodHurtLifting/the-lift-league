import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lift_league/services/momentum_service.dart';


class MomentumMeter extends StatefulWidget {
  final String userId;
  final double dropPerMissedDay;

  const MomentumMeter({
    super.key,
    required this.userId,
    this.dropPerMissedDay = 0.02,
  });

  @override
  State<MomentumMeter> createState() => _MomentumMeterState();
}

class _MomentumMeterState extends State<MomentumMeter> {
  final MomentumService _service = MomentumService();

  late final StreamController<Map<String, dynamic>> _momentumController;
  Timer? _timer;

  Stream<Map<String, dynamic>> get _momentumStream => _momentumController.stream;

  Color _colorFor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.yellow.shade700;
    return Colors.red;
  }

  @override
  void initState() {
    super.initState();
    _momentumController = StreamController<Map<String, dynamic>>();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final data = await _service.calculateMomentum(
        userId: widget.userId,
        dropPerMissedDay: widget.dropPerMissedDay,
      );
      if (!_momentumController.isClosed) {
        _momentumController.add(data);
      }
    });
    _service
        .calculateMomentum(
          userId: widget.userId,
          dropPerMissedDay: widget.dropPerMissedDay,
        )
        .then((data) {
      if (!_momentumController.isClosed) {
        _momentumController.add(data);
      }
    });
  }

  List<BarChartGroupData> _buildBars(List<double> trend, List<bool> drops) {
    final bars = <BarChartGroupData>[];
    for (int i = 0; i < trend.length; i++) {
      bars.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: trend[i],
            width: 6,
            color: drops[i] ? Colors.redAccent : Colors.blueAccent,
            borderRadius: BorderRadius.zero,
          ),
        ]),
      );
    }
    return bars;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _momentumController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _momentumStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final current = data['current'] as double;
        final average = data['average'] as double;
        final trend = (data['trend'] as List).cast<double>();
        final drops = (data['drops'] as List).cast<bool>();
        final color = _colorFor(current);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Momentum: ${current.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: current / 100,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  barGroups: _buildBars(trend, drops),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Lifetime Avg: ${average.toStringAsFixed(1)}%'),
            if (drops.isNotEmpty && drops.last)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Momentum dropped due to inactivity',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
