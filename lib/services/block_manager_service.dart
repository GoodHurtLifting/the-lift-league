import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/db_service.dart';

class BlockManagerService {
  final DBService _db = DBService();

  Future<void> executeUpdates(List<Map<String, dynamic>> lifts) async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final batch = firestore.batch();

    for (final lift in lifts) {
      final liftId = lift['liftId'] as int;
      await _db.updateLiftDefinition(
        liftId: liftId,
        liftName: lift['liftName'] ?? '',
        repScheme: lift['repScheme'] ?? '',
        scoreType: lift['scoreType'] ?? 'multiplier',
        scoreMultiplier: (lift['scoreMultiplier'] as num?)?.toDouble() ?? 0.0,
        youtubeUrl: lift['youtubeUrl'] ?? '',
        description: lift['description'] ?? '',
      );

      final doc = firestore.collection('lifts').doc(liftId.toString());
      batch.set(doc, lift, SetOptions(merge: true));

      final workoutInstanceIds = await _db.getWorkoutInstancesByLift(liftId);
      for (final wi in workoutInstanceIds) {
        await _db.updateLiftTotals(wi, liftId);
        await _db.writeWorkoutTotalsDirectly(
          workoutInstanceId: wi,
          userId: userId,
          syncToCloud: true,
        );
        final blockInstanceId = await _db.getBlockInstanceIdForWorkout(wi);
        await _db.recalculateBlockTotals(blockInstanceId);
      }
    }

    await batch.commit();
  }
}