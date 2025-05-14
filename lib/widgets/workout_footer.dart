import 'package:flutter/material.dart';
import 'package:lift_league/widgets/rest_timer.dart';

class WorkoutFooter extends StatelessWidget {
  final double workoutScore;
  final double totalWorkload;
  final double previousScore;

  const WorkoutFooter({
    super.key,
    required this.workoutScore,
    required this.totalWorkload,
    required this.previousScore,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white24)),
              color: Colors.black,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Workout Score: ${workoutScore.toStringAsFixed(1)}",
                        style: const TextStyle(color: Colors.white, fontSize: 18)),
                    Text("Previous Score: ${previousScore.toStringAsFixed(1)}",
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text("Total Workload: ${totalWorkload.toStringAsFixed(1)} lbs",
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const RestTimer(),
              ],
            ),
          ),
        ],
      ),
    );

  }
}
