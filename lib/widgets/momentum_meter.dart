import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lift_league/services/performance_service.dart';

class MomentumMeter extends StatefulWidget {
  final String userId;
  final double dropPerMissedDay;

  const MomentumMeter({
    super.key,
    required this.userId,
    this.dropPerMissedDay = 0.2,
  });

  @override
  State<MomentumMeter> createState() => _MomentumMeterState();
}

class _MomentumMeterState extends State<MomentumMeter> {
  final PerformanceService _service = PerformanceService();

  late final StreamController<double> _momentumController;
  Timer? _timer;

  Stream<double> get _momentumStream => _momentumController.stream;

  Color _colorFor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.yellow.shade700;
    return Colors.red;
  }

  @override
  void initState() {
    super.initState();
    _momentumController = StreamController<double>();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final pct = await _service.momentumPercent(userId: widget.userId);
      if (!_momentumController.isClosed) {
        _momentumController.add(pct);
      }
    });
    _service.momentumPercent(userId: widget.userId).then((pct) {
      if (!_momentumController.isClosed) {
        _momentumController.add(pct);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _momentumController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: _momentumStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pct = snapshot.data!;
        final color = _colorFor(pct);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 4),
            Text(
              'Momentum: ${pct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}
