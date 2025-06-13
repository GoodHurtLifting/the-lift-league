import 'dart:async';

import 'package:flutter/material.dart';
import '../services/db_service.dart';

class MomentumMeter extends StatelessWidget {
  final String userId;
  final int blockId;

  const MomentumMeter({super.key, required this.userId, required this.blockId});

  Color _colorFor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.yellow.shade700;
    return Colors.red;
  }

  Stream<Map<String, double>> _momentumStream() async* {
    final db = DBService();
    while (true) {
      final week = await db.getCurrentWeekNumber(blockId);
      final weekMomentum = await db.getWeeklyMomentum(userId, blockId, week);
      final runningAvg =
      await db.getRunningMomentumAverage(userId, blockId, week);
      yield {
        'momentum': weekMomentum,
        'average': runningAvg,
      };
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, double>>(
      stream: _momentumStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final momentum = snapshot.data!['momentum']!;
        final average = snapshot.data!['average']!;
        final color = _colorFor(momentum);
        final bool hype = momentum >= 80;
        final message =
        momentum >= average ? 'Crushing it!' : 'Keep pushing forward!';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Momentum: ${momentum.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: momentum / 100),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  color: color,
                  backgroundColor: Colors.grey.shade300,
                );
              },
            ),
            const SizedBox(height: 4),
            Text('Block Avg: ${average.toStringAsFixed(1)}%'),
            if (hype)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Momentum High! 🔥',
                  style:
                  TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                message,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          ],
        );
      },
    );
  }
}