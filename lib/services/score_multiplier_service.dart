import 'db_service.dart';

class ScoreMultiplierService {
  static const double _calibrationConstant = 0.21;

  /// Mid‑point assumption for progressive overload between
  /// repeated instances of the same custom lift.
  static const double deltaPerInstanceLbs = 7.5;

  double getMultiplier({
    required int sets,
    required int repsPerSet,
    bool isBodyweight = false,
  }) {
    if (isBodyweight) return 0.0;
    if (sets <= 0 || repsPerSet <= 0) return 0.0;
    return _calibrationConstant / (sets * repsPerSet);
  }

  /// Recomputes the score multiplier for a custom lift based on
  /// the first completed instance within a block.
  static Future<void> computeAndApplyForCustomLift({
    required int customLiftId,
    required int blockInstanceId,
  }) async {
    final db = await DBService.instance.database;

    await db.transaction((txn) async {
      final tmpl = await txn.query(
        'custom_lifts',
        columns: [
          'customWorkoutId',
          'sets',
          'repsPerSet',
          'position',
          'isBodyweight',
          'liftCatalogId'
        ],
        where: 'id = ?',
        whereArgs: [customLiftId],
        limit: 1,
      );
      if (tmpl.isEmpty) return;
      if ((tmpl.first['isBodyweight'] as int? ?? 0) == 1) return;

      final customWorkoutId = (tmpl.first['customWorkoutId'] as num).toInt();
      final sets = (tmpl.first['sets'] as num?)?.toInt() ?? 0;
      final repsPerSet = (tmpl.first['repsPerSet'] as num?)?.toInt() ?? 0;
      final position = (tmpl.first['position'] as num?)?.toInt() ?? 0;
      final liftCatalogId = tmpl.first['liftCatalogId'] as int?;
      if (sets <= 0 || repsPerSet <= 0) return;

      // 1) Locate the first completed lift_instance for this template
      final first = await txn.rawQuery('''
        SELECT li.liftInstanceId, li.liftId, MAX(le.weight) AS w0
        FROM lift_instances li
        JOIN workout_instances wi ON wi.workoutInstanceId = li.workoutInstanceId
        LEFT JOIN lift_entries le ON le.liftInstanceId = li.liftInstanceId
        WHERE wi.blockInstanceId = ? AND wi.workoutId = ? AND li.position = ?
        GROUP BY li.liftInstanceId
        HAVING COUNT(CASE WHEN (le.reps > 0 OR le.weight > 0) THEN 1 END) >= ?
        ORDER BY wi.week ASC, wi.slotIndex ASC
        LIMIT 1
      ''', [blockInstanceId, customWorkoutId, position, sets]);
      if (first.isEmpty) return;
      final w0 = (first.first['w0'] as num?)?.toDouble() ?? 0.0;
      final sampleLiftId = (first.first['liftId'] as num?)?.toInt();

      // 4) All occurrences of this lift in the block
      final occ = await txn.rawQuery('''
        SELECT li.liftInstanceId, li.liftId
        FROM lift_instances li
        JOIN workout_instances wi ON wi.workoutInstanceId = li.workoutInstanceId
        WHERE wi.blockInstanceId = ? AND wi.workoutId = ? AND li.position = ?
      ''', [blockInstanceId, customWorkoutId, position]);
      final n = occ.length;
      if (n <= 0) return;

      // 5-7) Project last-instance weight and compute multiplier
      final wLast = w0 + deltaPerInstanceLbs * (n - 1);
      final sumWeightsLast = wLast * sets;
      final totalReps = sets * repsPerSet;
      final multiplier = 100.0 / (sumWeightsLast * totalReps);

      await txn.update(
        'custom_lifts',
        {'scoreMultiplier': multiplier},
        where: 'id = ?',
        whereArgs: [customLiftId],
      );

      // Mirror multiplier to lifts table if a catalog entry exists.
      final int? liftId = liftCatalogId ?? sampleLiftId;
      if (liftId != null) {
        await txn.update('lifts', {'scoreMultiplier': multiplier},
            where: 'liftId = ?', whereArgs: [liftId]);
      }

      // Update all lift_instances in the block to use the new multiplier.
      if (occ.isNotEmpty) {
        final ids = occ.map((r) => (r['liftInstanceId'] as num).toInt()).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE lift_instances SET scoreMultiplier = ? WHERE liftInstanceId IN ($placeholders)',
          [multiplier, ...ids],
        );
      }
    });

    await DBService.instance.recalculateBlockTotals(blockInstanceId);
  }
}
