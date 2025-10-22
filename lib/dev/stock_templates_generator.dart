import 'package:lift_league/dev/block_data.dart' as blocksSrc;
import 'package:lift_league/dev/lift_data.dart' as liftsSrc;
import 'package:lift_league/dev/workout_data.dart' as workoutsSrc;


class StockSeed {
  final List<Map<String, Object?>> blocks;
  final List<Map<String, Object?>> workouts;
  final List<Map<String, Object?>> workoutsBlocks;
  final List<Map<String, Object?>> liftWorkouts;

  const StockSeed({
    required this.blocks,
    required this.workouts,
    required this.workoutsBlocks,
    required this.liftWorkouts,
  });
}

int? _parseReps(String? scheme) {
  if (scheme == null) return null;
  final match = RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*(?:reps|rep)', caseSensitive: false)
      .firstMatch(scheme);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  return null;
}

int _scoreTypeToInt(String? value) {
  switch (value?.toLowerCase()) {
    case 'bodyweight':
      return 1;
    case 'multiplier':
    default:
      return 0;
  }
}

StockSeed generateStockTemplates() {

  final blocks = <Map<String, Object?>>[];
  final workouts = <Map<String, Object?>>[];
  final workoutsBlocks = <Map<String, Object?>>[];
  final liftWorkouts = <Map<String, Object?>>[];

  final liftsById = {
    for (final lift in liftsSrc.liftDataList)
      (lift['liftId'] as int): lift,
  };

  for (final block in blocksSrc.blockDataList) {
    blocks.add({
      'blockId': block['blockId'],
      'blockName': block['blockName'],
      'scheduleType': block['scheduleType'],
      'numWorkouts': block['numWorkouts'],
    });

    final workoutIds = (block['workoutsIds'] as List).cast<int>();
    for (final workoutId in workoutIds) {
      workoutsBlocks.add({
        'blockId': block['blockId'],
        'workoutId': workoutId,
      });
    }
  }

  for (final workout in workoutsSrc.workoutDataList) {
    workouts.add({
      'workoutId': workout['workoutId'],
      'workoutName': workout['workoutName'],
    });

    final liftIds = (workout['liftIds'] as List).cast<int>();
    for (var index = 0; index < liftIds.length; index++) {
      final liftId = liftIds[index];
      final lift = liftsById[liftId];
      final sets = (lift?['numSets'] as int?) ?? 3;
      final reps = _parseReps(lift?['repScheme'] as String?);
      final multiplier = (lift?['scoreMultiplier'] as num?)?.toDouble();
      final isDumbbell = (lift?['isDumbbellLift'] as num?)?.toInt();
      final scoreType = _scoreTypeToInt(lift?['scoreType'] as String?);

      liftWorkouts.add({
        'workoutId': workout['workoutId'],
        'liftId': liftId,
        'numSets': sets,
        'position': index,
        if (reps != null) 'repsPerSet': reps,
        if (multiplier != null && scoreType == 0) 'multiplier': multiplier,
        'isBodyweight': scoreType == 1 ? 1 : 0,
        if (isDumbbell != null) 'isDumbbellLift': isDumbbell,
      });
    }
  }

  return StockSeed(
    blocks: blocks,
    workouts: workouts,
    workoutsBlocks: workoutsBlocks,
    liftWorkouts: liftWorkouts,
  );
}
