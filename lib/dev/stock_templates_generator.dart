class StockSeed {
  final List<Map<String, Object?>> blocks;
  final List<Map<String, Object?>> workoutsBlocks;
  final List<Map<String, Object?>> liftTemplates;
  StockSeed({required this.blocks, required this.workoutsBlocks, required this.liftTemplates});
}

/// TODO: adapt to your exact table/column names.
/// Assumes you already have `block_data.dart` and `workout_data.dart` moved into /dev.
import '../dev/block_data.dart' as blocksSrc; // or just '../dev/block_data.dart'
import 'package:lift_league/dev/workout_data.dart' as workoutsSrc;

StockSeed generateStockTemplates() {
  // Build rows from your existing dev data files.
  // Keep IDs stable (blockId, workoutId, catalogId).
  final blocks = <Map<String, Object?>>[];
  final workoutsBlocks = <Map<String, Object?>>[];
  final liftTemplates = <Map<String, Object?>>[];

  // Example sketch — replace with your real structures.
  for (final b in blocksSrc.blockDataList) {
    blocks.add({
      'blockId': b['blockId'],
      'blockName': b['blockName'],
      'numWeeks': b['numWeeks'] ?? 4,
      'workoutsPerWeek': b['workoutsPerWeek'] ?? 3,
      'scheduleType': b['scheduleType'] ?? 'standard',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Link workouts to blocks with a `position`
    final workoutIds = (b['workoutsIds'] as List).cast<int>();
    for (var i = 0; i < workoutIds.length; i++) {
      workoutsBlocks.add({
        'blockId': b['blockId'],
        'workoutId': workoutIds[i],
        'position': i,
      });
    }
  }

  // For each workout, emit its lift templates
  for (final w in workoutsSrc.workoutDataList) {
    final lifts = (w['lifts'] as List).cast<Map<String, Object?>>();
    for (var pos = 0; pos < lifts.length; pos++) {
      final l = lifts[pos];
      liftTemplates.add({
        'workoutId': w['workoutId'],
        'catalogId': l['catalogId'],         // must map your lift names → catalogIds
        'position': pos,
        'sets': l['numSets'],
        'repsPerSet': l['repsPerSet'],
        'baseMultiplier': l['scoreMultiplier'],
        'scoreType': l['scoreType'] ?? 0,    // 0=multiplier, 1=bodyweight (match your constants)
        'logUnilaterally': l['isDumbbellLift'] ?? 0,
        'instructions': l['instructions'] ?? '',
      });
    }
  }

  return StockSeed(
    blocks: blocks,
    workoutsBlocks: workoutsBlocks,
    liftTemplates: liftTemplates,
  );
}
