import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/custom_block_models.dart';
import '../services/calculations.dart';

typedef CustomWorkout = WorkoutDraft;

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

  Future<CustomBlock?> getCustomBlockById(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .doc(id)
        .get();
    final data = doc.data();
    if (data == null) return null;
    data['id'] = int.tryParse(doc.id) ?? 0;
    return CustomBlock.fromMap(data);
  }

  Future<void> saveCustomBlock(CustomBlock block,
      {Uint8List? coverImageBytes}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'unauthenticated', message: 'User not signed in');
    }

    String? imageUrl;
    if (coverImageBytes != null) {
      final fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('block_covers/$fileName');
      final task = await ref.putData(
        coverImageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await task.ref.getDownloadURL();
    } else {
      imageUrl = block.coverImagePath;
    }

    final blockData = {
      'name': block.name,
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'scheduleType': block.scheduleType,
      'isDraft': block.isDraft,
      'coverImageUrl': imageUrl,
      'ownerId': user.uid,
      'source': 'web_custom_builder',
      'workouts': block.workouts
          .map((w) => {
                'id': w.id,
                'dayIndex': w.dayIndex,
                'name': w.name,
                'lifts': w.lifts
                    .map((l) => {
                          'name': l.name,
                          'sets': l.sets,
                          'repsPerSet': l.repsPerSet,
                          'multiplier': l.multiplier,
                          'isBodyweight': l.isBodyweight,
                          'isDumbbellLift': l.isDumbbellLift,
                        })
                    .toList(),
              })
          .toList(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set(blockData);

    await FirebaseFirestore.instance
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set(blockData);
  }

  /// Creates a new block run for [block] and returns the run document ID.
  ///
  /// The run document stores a sequential [runNumber] and an empty
  /// `workout_totals` subcollection so that scores can be populated as the
  /// user logs workouts.
  Future<String> startBlockRun(CustomBlock block) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'unauthenticated', message: 'User not signed in');
    }

    final runsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .where('blockName', isEqualTo: block.name)
        .get();

    final runNumber = runsSnap.docs.length + 1;

    final runRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc();

    await runRef.set({
      'blockName': block.name,
      'blockId': block.id,
      'createdAt': FieldValue.serverTimestamp(),
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'runNumber': runNumber,
    });

    final dist = _generateWebWorkoutDistribution(
        block.workouts,
        block.numWeeks,
        block.daysPerWeek,
        block.scheduleType);

    for (int i = 0; i < dist.length; i++) {
      final item = dist[i];
      final workout = item['workout'] as CustomWorkout;
      final week = item['week'] as int;
      final dayIndex = item['dayIndex'] as int;

      final workoutRef = runRef.collection('workouts').doc(i.toString());
      await workoutRef.set({
        'name': workout.name,
        'week': week,
        'dayIndex': dayIndex,
      });

      await runRef.collection('workout_totals').doc(i.toString()).set({
        'workoutWorkload': 0.0,
        'workoutScore': 0.0,
        'runNumber': runNumber,
        'blockId': block.id,
      });

      for (int l = 0; l < workout.lifts.length; l++) {
        final lift = workout.lifts[l];
        await workoutRef.collection('lifts').doc(l.toString()).set({
          'name': lift.name,
          'sets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'multiplier': lift.multiplier,
          'isBodyweight': lift.isBodyweight,
          'isDumbbellLift': lift.isDumbbellLift,
          'entries': List.generate(lift.sets, (_) {
            return {
              'reps': 0,
              'weight': 0.0,
              'liftWorkload': 0.0,
              'liftScore': 0.0,
              'liftReps': 0,
            };
          }),
          'liftWorkload': 0.0,
          'liftScore': 0.0,
          'liftReps': 0,
        });
      }
    }

    return runRef.id;
  }

  Future<void> updateLiftTotals(
      String runId, int workoutIndex, int liftIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final liftRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(runId)
        .collection('workouts')
        .doc(workoutIndex.toString())
        .collection('lifts')
        .doc(liftIndex.toString());

    final liftDoc = await liftRef.get();
    final data = liftDoc.data();
    if (data == null) return;

    final entries =
        (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final multiplier = (data['multiplier'] as num?)?.toDouble() ?? 1.0;
    final isDumbbell = data['isDumbbellLift'] == true;
    final isBodyweight = data['isBodyweight'] == true;
    final scoreType = isBodyweight ? 'bodyweight' : 'multiplier';

    final liftWorkload =
        getLiftWorkloadFromDb(entries, isDumbbellLift: isDumbbell);
    final liftScore = calculateLiftScoreFromEntries(entries, multiplier,
        isDumbbellLift: isDumbbell, scoreType: scoreType);
    final liftReps =
        getLiftRepsFromDb(entries, isDumbbellLift: isDumbbell);

    await liftRef.update({
      'liftWorkload': liftWorkload,
      'liftScore': liftScore,
      'liftReps': liftReps,
    });
  }

  Future<void> updateWorkoutTotals(String runId, int workoutIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final workoutRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(runId)
        .collection('workouts')
        .doc(workoutIndex.toString());

    final liftsSnap = await workoutRef.collection('lifts').get();

    double totalWorkload = 0.0;
    double totalScore = 0.0;

    for (final doc in liftsSnap.docs) {
      totalWorkload += (doc.data()['liftWorkload'] as num?)?.toDouble() ?? 0.0;
      totalScore += (doc.data()['liftScore'] as num?)?.toDouble() ?? 0.0;
    }

    final avgScore =
        liftsSnap.docs.isNotEmpty ? totalScore / liftsSnap.docs.length : 0.0;

    final totalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(runId)
        .collection('workout_totals')
        .doc(workoutIndex.toString());

    await totalsRef.update({
      'workoutWorkload': totalWorkload,
      'workoutScore': avgScore,
    });
  }

  Future<void> deleteCustomBlock(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userDoc.collection('custom_blocks').doc(id).delete();
    await userDoc.collection('customBlockRefs').doc(id).delete();

    final globalDoc =
        FirebaseFirestore.instance.collection('custom_blocks').doc(id);
    final snap = await globalDoc.get();
    if (snap.exists && snap.data()?['ownerId'] == user.uid) {
      await globalDoc.delete();
    }
  }

  /// Generates an ordered distribution of [workouts] for web-based blocks.
  ///
  /// The resulting list contains a map for each scheduled workout with the
  /// following keys:
  ///
  /// * `workout`  – the template [CustomWorkout] object
  /// * `week`     – the 1-based week number
  /// * `dayIndex` – the zero-based day index within the week (0 = Monday)
  ///
  /// Only the `standard` and `ab_alternate` schedule types are supported. The
  /// `weeks` parameter must be between 3 and 6 inclusive and `daysPerWeek` must
  /// be between 2 and 6 inclusive.
  List<Map<String, dynamic>> _generateWebWorkoutDistribution(
    List<CustomWorkout> workouts,
    int weeks,
    int daysPerWeek,
    String scheduleType,
  ) {
    assert(weeks >= 3 && weeks <= 6, 'weeks must be between 3 and 6');
    assert(daysPerWeek >= 2 && daysPerWeek <= 6,
        'daysPerWeek must be between 2 and 6');

    final distribution = <Map<String, dynamic>>[];

    if (scheduleType == 'ab_alternate' &&
        daysPerWeek == 3 &&
        workouts.length == 2) {
      // Alternate pattern for A/B programs.
      final List<List<int>> patterns = [
        [0, 1, 0],
        [1, 0, 1],
      ];
      for (int week = 0; week < weeks; week++) {
        final pattern = patterns[week % 2];
        for (int day = 0; day < daysPerWeek; day++) {
          final workoutIndex = pattern[day % pattern.length];
          distribution.add({
            'workout': workouts[workoutIndex],
            'week': week + 1,
            'dayIndex': day,
          });
        }
      }
      return distribution;
    }

    // Standard sequential distribution.
    int index = 0;
    final totalSlots = weeks * daysPerWeek;
    for (int slot = 0; slot < totalSlots; slot++) {
      final week = (slot ~/ daysPerWeek) + 1;
      final day = slot % daysPerWeek;
      distribution.add({
        'workout': workouts[index % workouts.length],
        'week': week,
        'dayIndex': day,
      });
      index++;
    }

    return distribution;
  }
}
