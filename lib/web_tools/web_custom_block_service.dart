import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/custom_block_models.dart';

class WebCustomBlockService {
  Future<List<Map<String, dynamic>>> getCustomBlocks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = int.tryParse(d.id) ?? 0;
      return data;
    }).toList();
  }

  /// Creates a new block run for [block] and returns the run document ID.
  Future<String> startBlockRun(CustomBlock block) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'unauthenticated', message: 'User not signed in');
    }

    final runRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc();

    await runRef.set({
      'blockName': block.name,
      'createdAt': FieldValue.serverTimestamp(),
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
    });

    for (int wIndex = 0; wIndex < block.workouts.length; wIndex++) {
      final workout = block.workouts[wIndex];
      final workoutRef =
          runRef.collection('workouts').doc(wIndex.toString());
      await workoutRef.set({
        'name': workout.name,
        'dayIndex': workout.dayIndex,
      });

      for (int lIndex = 0; lIndex < workout.lifts.length; lIndex++) {
        final lift = workout.lifts[lIndex];
        await workoutRef.collection('lifts').doc(lIndex.toString()).set({
          'name': lift.name,
          'sets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'multiplier': lift.multiplier,
          'isBodyweight': lift.isBodyweight,
          'isDumbbellLift': lift.isDumbbellLift,
          'completedSets': <int>[],
        });
      }
    }

    return runRef.id;
  }
}