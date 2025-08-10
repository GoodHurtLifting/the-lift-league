import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/custom_block_models.dart';
import '../services/calculations.dart';
import 'web_custom_block_service.dart';
import 'web_lift_entry.dart';

class WebWorkoutLog extends StatefulWidget {
  final String runId;
  final int workoutIndex;
  final CustomBlock block;
  final WorkoutDraft workout;
  const WebWorkoutLog({
    super.key,
    required this.runId,
    required this.workoutIndex,
    required this.block,
    required this.workout,
  });

  @override
  State<WebWorkoutLog> createState() => _WebWorkoutLogState();
}

class _WebWorkoutLogState extends State<WebWorkoutLog> {
  late final WorkoutDraft workout;

  final Map<int, List<TextEditingController>> _repCtrls = {};
  final Map<int, List<TextEditingController>> _weightCtrls = {};

  final Map<int, List<Map<String, dynamic>>> _prevEntries = {};

  final Map<int, double> _liftScores = {};
  final Map<int, double> _liftWorkloads = {};
  double _workoutScore = 0.0;
  double _workoutWorkload = 0.0;
  double? _previousScore;
  bool _workoutFinished = false;

  @override
  void initState() {
    super.initState();
    workout = widget.workout;
    _loadCompletion();
  }

  Future<void> _loadCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final workoutDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString())
        .get();
    _workoutFinished = workoutDoc.data()?['completedAt'] != null;
    final List<double> prevScores = [];
    for (int i = 0; i < workout.lifts.length; i++) {
      final liftDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('block_runs')
          .doc(widget.runId)
          .collection('workouts')
          .doc(widget.workoutIndex.toString())
          .collection('lifts')
          .doc(i.toString())
          .get();

      final List<dynamic> entriesData = liftDoc.data()?['entries'] ?? [];
      print('Loaded entries for lift $i: $entriesData');
      _repCtrls[i] = List.generate(workout.lifts[i].sets, (index) {
        final ctrl = TextEditingController();
        if (index < entriesData.length) {
          final e = entriesData[index] as Map<String, dynamic>;
          ctrl.text = e['reps']?.toString() ?? '';
        }
        return ctrl;
      });
      _weightCtrls[i] = List.generate(workout.lifts[i].sets, (index) {
        final ctrl = TextEditingController();
        if (index < entriesData.length) {
          final e = entriesData[index] as Map<String, dynamic>;
          final w = (e['weight'] as num?)?.toDouble();
          if (w != null && w > 0) {
            ctrl.text = w % 1 == 0 ? w.toInt().toString() : w.toString();
          }
        }
        return ctrl;
      });

      final prevEntriesList = await _getPreviousEntries(i);
      _prevEntries[i] = prevEntriesList;
      if (prevEntriesList.isNotEmpty) {
        final lift = workout.lifts[i];
        final prevScore = calculateLiftScoreFromEntries(
          prevEntriesList,
          lift.multiplier,
          isDumbbellLift: lift.isDumbbellLift,
          scoreType: lift.isBodyweight ? 'bodyweight' : 'multiplier',
        );
        prevScores.add(prevScore);
      }
    }
    _recalculateTotals();
    _previousScore =
        prevScores.isEmpty ? null : calculatePreviousWorkoutScore(prevScores);
    if (mounted) setState(() {});
  }

  /// Returns past workout documents for [workout.name] sorted by most recent
  /// completion. This mimics a shared `getPreviousWorkoutInstances` service.
  /// TODO: replace with a dedicated service method.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getPreviousWorkoutInstances(String userId, String workoutName) async {
    final runsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('block_runs')
        .orderBy('createdAt', descending: true)
        .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> workouts = [];
    for (final run in runsSnap.docs) {
      final snap = await run.reference
          .collection('workouts')
          .where('name', isEqualTo: workoutName)
          .get();
      for (final doc in snap.docs) {
        final completedAt = doc.data()['completedAt'] as Timestamp?;
        if (completedAt == null) continue;
        if (run.id == widget.runId &&
            doc.id == widget.workoutIndex.toString()) {
          continue;
        }
        workouts.add(doc);
      }
    }

    workouts.sort((a, b) {
      final aTime = (a.data()['completedAt'] as Timestamp).toDate();
      final bTime = (b.data()['completedAt'] as Timestamp).toDate();
      return bTime.compareTo(aTime);
    });
    if (workouts.isNotEmpty) {
      final latestRunId = workouts.first.reference.parent.parent?.id;
      print('Found previous workout from run $latestRunId');
    } else {
      print('No previous completed workout found for $workoutName');
    }
    return workouts;
  }

  Future<List<Map<String, dynamic>>> _getPreviousEntries(int liftIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final workouts =
        await _getPreviousWorkoutInstances(user.uid, workout.name);
    if (workouts.isEmpty) return [];

    final prevWorkout = workouts.first;

    final liftsCol = prevWorkout.reference.collection('lifts');

    // Try to match by a unique liftId if present, otherwise by index
    DocumentSnapshot<Map<String, dynamic>>? prevLiftDoc;
    int? liftId;
    try {
      final dynamic lift = workout.lifts[liftIndex];
      liftId = lift.liftId ?? lift.id;
    } catch (_) {}

    if (liftId != null) {
      final query = await liftsCol.where('liftId', isEqualTo: liftId).limit(1).get();
      if (query.docs.isNotEmpty) {
        prevLiftDoc = query.docs.first;
      }
    }

    prevLiftDoc ??= await liftsCol.doc(liftIndex.toString()).get();

    final List<dynamic> prevData = prevLiftDoc.data()?['entries'] ?? [];
    return prevData
        .map<Map<String, dynamic>>((e) {
          // Normalize legacy keys ('prev' and 'lift') to the current
          // 'reps'/'weight' structure so older workout logs still display
          // correctly in the UI.
          if (e is Map<String, dynamic>) {
            final reps = e['reps'] ?? e['prev'] ?? 0;
            final weight = e['weight'] ?? e['lift'] ?? 0;
            return {'reps': reps, 'weight': weight};
          }
          return {'reps': 0, 'weight': 0};
        })
        .toList();
  }

  void _recalculateTotals() {
    _workoutScore = 0.0;
    _workoutWorkload = 0.0;
    _liftScores.clear();
    _liftWorkloads.clear();
    for (int i = 0; i < workout.lifts.length; i++) {
      final repCtrls = _repCtrls[i] ?? [];
      final weightCtrls = _weightCtrls[i] ?? [];
      final lift = workout.lifts[i];
      final workload = getLiftWorkload(
        repCtrls,
        weightCtrls,
        isDumbbellLift: lift.isDumbbellLift,
      );
      final score = getLiftScore(
        repCtrls,
        weightCtrls,
        lift.multiplier,
        isDumbbellLift: lift.isDumbbellLift,
        scoreType: lift.isBodyweight ? 'bodyweight' : 'multiplier',
      );
      _liftWorkloads[i] = workload;
      _liftScores[i] = score;
    }
    if (_liftScores.isNotEmpty) {
      _workoutWorkload =
          _liftWorkloads.values.fold(0.0, (a, b) => a + b);
      _workoutScore =
          _liftScores.values.reduce((a, b) => a + b) / _liftScores.length;
    }
  }

  Future<void> _saveLift(int liftIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reps = _repCtrls[liftIndex]!
        .map((c) => int.tryParse(c.text) ?? 0)
        .toList();
    final weights = _weightCtrls[liftIndex]!
        .map((c) => double.tryParse(c.text) ?? 0.0)
        .toList();

    final entries = <Map<String, dynamic>>[];
    for (int i = 0; i < reps.length; i++) {
      entries.add({'reps': reps[i], 'weight': weights[i]});
    }

    final liftRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString())
        .collection('lifts')
        .doc(liftIndex.toString());

    await liftRef.set({'entries': entries}, SetOptions(merge: true));

    await WebCustomBlockService()
        .updateLiftTotals(widget.runId, widget.workoutIndex, liftIndex);

   // _prevEntries[liftIndex] = List.from(entries);
    _recalculateTotals();
    if (mounted) setState(() {});

    await _updateWorkoutTotals();
  }

  Future<void> _updateWorkoutTotals() async {
    await WebCustomBlockService()
        .updateWorkoutTotals(widget.runId, widget.workoutIndex);
  }

  Future<void> _finishWorkout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    for (int i = 0; i < workout.lifts.length; i++) {
      await _saveLift(i);
    }
    final workoutRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString());
    // Record when this workout was finished by stamping the current time.
    await workoutRef.set(
      {
        'completedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    if (!mounted) return;
    setState(() => _workoutFinished = true);
    Navigator.pop(context);
  }

  Future<bool> _confirmExit() async {
    if (_workoutFinished) return true;
    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Workout?'),
            content: const Text(
                'Your progress is saved automatically, but the workout is not finished. Exit anyway?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
    return shouldLeave;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(title: Text(workout.name)),
        body: ListView.builder(
          itemCount: workout.lifts.length + 1,
          itemBuilder: (context, index) {
            if (index == workout.lifts.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workout Score: ${_workoutScore.toStringAsFixed(1)}'),
                    Text(
                        'Previous Score: ${_previousScore != null ? _previousScore!.toStringAsFixed(1) : '--'}'),
                    Text('Total Workload: ${_workoutWorkload.toStringAsFixed(1)} lbs'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _finishWorkout,
                      child: const Text('Finish Workout'),
                    ),
                  ],
                ),
              );
            }

            final lift = workout.lifts[index];
            final prev = _prevEntries[index] ?? [];

            final repCtrls =
                _repCtrls[index] ??= List.generate(lift.sets, (_) => TextEditingController());
            final weightCtrls = _weightCtrls[index] ??=
                List.generate(lift.sets, (_) => TextEditingController());

            return WebLiftEntry(
              liftIndex: index,
              lift: lift,
              previousEntries: prev,
              repControllers: repCtrls,
              weightControllers: weightCtrls,
              onChanged: (_, __) {
                _saveLift(index);
              },
            );
          },
        ),
      ),
    );
  }
}
