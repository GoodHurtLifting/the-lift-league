import 'package:flutter/material.dart';
import 'package:lift_league/services/performance_service.dart';

class ConsistencyMeter extends StatefulWidget {
  final String userId;
  final int blockId;

  const ConsistencyMeter({
    super.key,
    required this.userId,
    required this.blockId,
  });

  @override
  State<ConsistencyMeter> createState() => _ConsistencyMeterState();
}

class _ConsistencyMeterState extends State<ConsistencyMeter> {
  late final Stream<ConsistencySummary> _consistencyStream;

  @override
  void initState() {
    super.initState();
    _consistencyStream = Stream.periodic(const Duration(seconds: 1)).asyncMap(
      (_) => PerformanceService().consistency(
        userId: widget.userId,
        blockInstanceId: widget.blockId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConsistencySummary>(
      stream: _consistencyStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
              height: 60,
              child: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 60, child: Center(child: CircularProgressIndicator()));
        }
        final summary = snapshot.data!;
        final progress = summary.percent / 100.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 6),
            Text(
              "${summary.percent.toStringAsFixed(0)}% consistency",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );
      },
    );
  }
}