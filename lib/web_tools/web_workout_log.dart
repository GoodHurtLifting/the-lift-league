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
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

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
          final r = _toInt(e['reps']);              // uses the helper you added earlier
          if (r > 0) ctrl.text = r.toString();      // leave blank if 0 or null
        }
        return ctrl;
      });
      _weightCtrls[i] = List.generate(workout.lifts[i].sets, (index) {
        final ctrl = TextEditingController();
        if (index < entriesData.length) {
          final e = entriesData[index] as Map<String, dynamic>;
          final w = _toDouble(e['weight']);
          if (w > 0) {
            ctrl.text = (w % 1 == 0) ? w.toInt().toString() : w.toStringAsFixed(1);
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
  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  _getPreviousWorkoutInstances(String userId, String workoutName) async {

    // ---------- Pass A: search current run for earlier instance by name ----------
    final currentRunRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('block_runs')
        .doc(widget.runId);

    final List<DocumentSnapshot<Map<String, dynamic>>> candidates = [];

    try {
      final byNameSnap = await currentRunRef
          .collection('workouts')
          .where('name', isEqualTo: workoutName)
          .get();

      final filtered = byNameSnap.docs.where((d) {
        final done = d.data()['completedAt'] as Timestamp?;
        final isCurrent = d.id == widget.workoutIndex.toString();
        return done != null && !isCurrent;
      }).toList();

      filtered.sort((a, b) {
        final aTs = (a.data()['completedAt'] as Timestamp).millisecondsSinceEpoch;
        final bTs = (b.data()['completedAt'] as Timestamp).millisecondsSinceEpoch;
        return bTs.compareTo(aTs);
      });

      if (filtered.isNotEmpty) {
        // add just the most recent prior in this run
        candidates.add(filtered.first);
      }
    } catch (_) {
      // If 'name' is missing on workout docs, skip Pass A.
    }

    if (candidates.isNotEmpty) {
      print('Found previous within current run for "$workoutName" -> workoutId=${candidates.first.id}');
      return candidates;
    }

    // ---------- Pass B: search prior runs of the SAME block by index ----------
    final runsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('block_runs')
        .where('blockName', isEqualTo: widget.block.name)
        .get();

    final runs = runsSnap.docs;
    runs.sort((a, b) {
      final aTs = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });

    final List<DocumentSnapshot<Map<String, dynamic>>> workouts = [];

    for (final run in runs) {
      if (run.id == widget.runId && !_workoutFinished) continue;

      final wDoc = await run.reference
          .collection('workouts')
          .doc(widget.workoutIndex.toString())
          .get();

      final completedAt = wDoc.data()?['completedAt'] as Timestamp?;
      if (completedAt != null) {
        workouts.add(wDoc);
        break; // most recent prior found
      } else {
        // Optional fallback by name (in case index schema changed)
        try {
          final byName = await run.reference
              .collection('workouts')
              .where('name', isEqualTo: workoutName)
              .limit(1)
              .get();
          if (byName.docs.isNotEmpty) {
            final d = byName.docs.first;
            final done = d.data()['completedAt'] as Timestamp?;
            if (done != null) {
              workouts.add(d);
              break;
            }
          }
        } catch (_) {
          // ignore and continue
        }
      }
    }

    if (workouts.isNotEmpty) {
      final latestRunId = workouts.first.reference.parent.parent?.id;
      print('Found previous workout index ${widget.workoutIndex} from prior run $latestRunId');
    } else {
      print('No previous completed workout found for "$workoutName" (block=${widget.block.name})');
    }
    return workouts;
  }

  Future<bool> _hasAnyPriorCompletedInstance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // --- A) Look in the CURRENT run for an earlier completed instance ---
    final currentRunWorkouts = userRef
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts');

    try {
      // Prefer matching by name (safer if workout order changes)
      final sameNameSnap =
      await currentRunWorkouts.where('name', isEqualTo: workout.name).get();

      final hasEarlierCompletedHere = sameNameSnap.docs.any((d) {
        if (d.id == widget.workoutIndex.toString()) return false; // skip current
        final done = d.data()['completedAt'] as Timestamp?;
        if (done == null) return false;
        final idx = int.tryParse(d.id) ?? 1 << 30;
        return idx < widget.workoutIndex; // earlier instance in this run
      });

      if (hasEarlierCompletedHere) return true;
    } catch (_) {
      // Fallback: check the immediate previous index only (if name missing)
      final prevIdxDoc =
      await currentRunWorkouts.doc((widget.workoutIndex - 1).toString()).get();
      final done = prevIdxDoc.data()?['completedAt'] as Timestamp?;
      if (done != null) return true;
    }

    // --- B) Look in PRIOR runs of the SAME block for a completed instance ---
    final runsSnap = await userRef
        .collection('block_runs')
        .where('blockName', isEqualTo: widget.block.name)
        .get();

    // Sort newest -> oldest (just for determinism)
    final runs = runsSnap.docs
      ..sort((a, b) {
        final aTs =
            (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTs =
            (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });

    for (final run in runs) {
      if (run.id == widget.runId) continue; // skip current run

      // Try by exact index first
      final wByIndex =
      await run.reference.collection('workouts').doc(widget.workoutIndex.toString()).get();
      final byIndexDone = wByIndex.data()?['completedAt'] as Timestamp?;
      if (byIndexDone != null) return true;

      // Fallback by name
      try {
        final byName = await run.reference
            .collection('workouts')
            .where('name', isEqualTo: workout.name)
            .limit(1)
            .get();
        if (byName.docs.isNotEmpty) {
          final done = byName.docs.first.data()['completedAt'] as Timestamp?;
          if (done != null) return true;
        }
      } catch (_) {
        // ignore and continue
      }
    }

    // No completed instance found anywhere
    return false;
  }

  Future<List<Map<String, dynamic>>> _getPreviousEntries(int liftIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // Show previous ONLY if a completed instance exists before now (this run or any prior run).
    final hasPrior = await _hasAnyPriorCompletedInstance();
    if (!hasPrior) return [];

    // (rest stays the same)
    final workouts = await _getPreviousWorkoutInstances(user.uid, workout.name);
    if (workouts.isEmpty) return [];

    final prevWorkout = workouts.first;
    final liftsCol = prevWorkout.reference.collection('lifts');

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
    return prevData.cast<Map<String, dynamic>>();
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
        .map((c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim()))
        .toList();
    final weights = _weightCtrls[liftIndex]!
        .map((c) => c.text.trim().isEmpty ? null : double.tryParse(c.text.trim()))
        .toList();

    final entries = <Map<String, dynamic>>[];
    for (int i = 0; i < reps.length; i++) {
      entries.add({
        if (reps[i] != null) 'reps': reps[i],
        if (weights[i] != null) 'weight': weights[i],
      });
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
        'name': workout.name,
        'blockName': widget.block.name,
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
