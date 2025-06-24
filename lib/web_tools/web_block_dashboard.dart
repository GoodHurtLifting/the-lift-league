import 'package:flutter/material.dart';
import '../models/custom_block_models.dart';

class WebBlockDashboard extends StatelessWidget {
  final CustomBlock block;
  const WebBlockDashboard({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(block.name),
      ),
      body: ListView.builder(
        itemCount: block.workouts.length,
        itemBuilder: (context, index) {
          final workout = block.workouts[index];
          final week = index ~/ block.daysPerWeek + 1;
          final day = index % block.daysPerWeek + 1;
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text('Week $week - Day $day: ${workout.name}'),
              children: workout.lifts
                  .map(
                    (l) => ListTile(
                      title: Text(l.name),
                      subtitle: Text('${l.sets} x ${l.repsPerSet}'),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}
