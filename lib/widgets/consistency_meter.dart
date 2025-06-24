import 'package:flutter/material.dart';
import 'package:lift_league/services/consistency_service.dart';

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
  late final Stream<Map<String, dynamic>> _consistencyStream;

  @override
  void initState() {
    super.initState();
    _consistencyStream = Stream.periodic(const Duration(seconds: 1)).asyncMap(
      (_) => ConsistencyService().getWeeklyConsistency(
        userId: widget.userId,
        blockInstanceId: widget.blockId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _consistencyStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
              height: 60,
              child: Center(child: Text('Error: ${snapshot.error.toString()}')));
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 60, child: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        final completed = data['completed'] as int;
        final scheduled = data['scheduled'] as int;
        final percentage = data['percentage'] as double;
        final streak = data['streak'] as int;

        final progress = scheduled == 0 ? 0.0 : completed / scheduled;

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
              '$completed of $scheduled workouts completed this week',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}% consistency this week',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (streak > 1)
              Text(
                '$streak weeks in a row!',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
          ],
        );
      },
    );
  }
}