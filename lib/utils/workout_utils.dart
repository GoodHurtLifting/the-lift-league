import 'package:lift_league/dev/block_data.dart';
import 'package:lift_league/dev/workout_data.dart';

List<String> getOrderedWorkoutNamesForBlock(int blockId) {
  final block = blockDataList.firstWhere(
        (b) => b['blockId'] == blockId,
    orElse: () => {},
  );

  if (block.isEmpty) return [];

  final List workoutIds = block['workoutsIds'];
  final List<String> workoutNames = [];

  for (final id in workoutIds) {
    final workout = workoutDataList.firstWhere(
          (w) => w['workoutId'] == id,
      orElse: () => {},
    );
    if (workout.isNotEmpty) {
      workoutNames.add(workout['workoutName']);
    }
  }

  return workoutNames;
}
