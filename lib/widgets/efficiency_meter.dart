import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lift_league/services/notifications_service.dart';
import 'package:lift_league/services/performance_service.dart';

class EfficiencyMeter extends StatefulWidget {
  final String userId;
  final String blockId;
  const EfficiencyMeter({super.key, required this.userId, required this.blockId});

  @override
  State<EfficiencyMeter> createState() => _EfficiencyMeterState();
}

class _EfficiencyMeterState extends State<EfficiencyMeter> {
  bool _notified = false;

  late final StreamController<EfficiencyStats> _statsController;
  Timer? _timer;

  Stream<EfficiencyStats> get _statsStream => _statsController.stream;

  @override
  void initState() {
    super.initState();
    _statsController = StreamController<EfficiencyStats>();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final stats = await PerformanceService().efficiencyMeter(
        userId: widget.userId,
        blockInstanceId: int.tryParse(widget.blockId) ?? 0,
      );
      _handleNotification(stats.efficient);
      if (!_statsController.isClosed) {
        _statsController.add(stats);
      }
    });
    PerformanceService()
        .efficiencyMeter(
          userId: widget.userId,
          blockInstanceId: int.tryParse(widget.blockId) ?? 0,
        )
        .then((stats) {
      _handleNotification(stats.efficient);
      if (!_statsController.isClosed) {
        _statsController.add(stats);
      }
    });
  }

  void _handleNotification(bool efficient) {
    if (efficient && !_notified) {
      NotificationService().showSimpleNotification(
        'Great work!',
        'Efficiency improved this week!',
      );
      _notified = true;
    } else if (!efficient) {
      _notified = false;
    }
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
    return StreamBuilder<EfficiencyStats>(
      stream: _statsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final progress = data.progress;
        final avgLift = data.avgLift;
        final trend = data.trend;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  'Avg lift: ${avgLift.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 16),
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