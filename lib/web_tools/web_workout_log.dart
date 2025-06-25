import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/custom_block_models.dart';

class WebWorkoutLog extends StatefulWidget {
  final String runId;
  final int workoutIndex;
  final CustomBlock block;
  const WebWorkoutLog({super.key, required this.runId, required this.workoutIndex, required this.block});

  @override
  State<WebWorkoutLog> createState() => _WebWorkoutLogState();
}

class _WebWorkoutLogState extends State<WebWorkoutLog> {
  late final WorkoutDraft workout;

  final Map<int, List<TextEditingController>> _repCtrls = {};
  final Map<int, List<TextEditingController>> _weightCtrls = {};

  final Map<int, List<Map<String, dynamic>>> _prevEntries = {};

  @override
  void initState() {
    super.initState();
    workout = widget.block.workouts[widget.workoutIndex];
    _loadCompletion();
  }

  Future<void> _loadCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
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

      _prevEntries[i] = await _getPreviousEntries(i);
    }
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _getPreviousEntries(int liftIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final runDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .get();

    final currentRunNumber = (runDoc.data()?['runNumber'] as num?)?.toInt() ?? 1;

    final prevRunSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .where('blockName', isEqualTo: widget.block.name)
        .where('runNumber', isLessThan: currentRunNumber)
        .orderBy('runNumber', descending: true)
        .limit(1)
        .get();

    if (prevRunSnap.docs.isEmpty) return [];

    final prevRunId = prevRunSnap.docs.first.id;
    final prevLiftDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(prevRunId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString())
        .collection('lifts')
        .doc(liftIndex.toString())
        .get();

    final List<dynamic> prevData = prevLiftDoc.data()?['entries'] ?? [];
    return prevData.cast<Map<String, dynamic>>();
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

    await liftRef.update({'entries': entries});

    final liftDoc = await liftRef.get();
    final data = liftDoc.data() ?? {};
    final multiplier = (data['multiplier'] as num?)?.toDouble() ?? 1.0;
    final isDumbbell = data['isDumbbellLift'] == true;
    final isBodyweight = data['isBodyweight'] == true;
    final scoreType = isBodyweight ? 'bodyweight' : 'multiplier';

    final liftWorkload = getLiftWorkloadFromDb(entries,
        isDumbbellLift: isDumbbell);
    final liftScore = calculateLiftScoreFromEntries(entries, multiplier,
        isDumbbellLift: isDumbbell, scoreType: scoreType);
    final liftReps = getLiftRepsFromDb(entries, isDumbbellLift: isDumbbell);

    await liftRef.update({
      'liftWorkload': liftWorkload,
      'liftScore': liftScore,
      'liftReps': liftReps,
    });

    await _updateWorkoutTotals();
  }

  Future<void> _updateWorkoutTotals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final workoutRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString());

    final liftsSnap = await workoutRef.collection('lifts').get();

    double totalWorkload = 0.0;
    double totalScore = 0.0;

    for (final doc in liftsSnap.docs) {
      totalWorkload +=
          (doc.data()['liftWorkload'] as num?)?.toDouble() ?? 0.0;
      totalScore += (doc.data()['liftScore'] as num?)?.toDouble() ?? 0.0;
    }

    final avgScore = liftsSnap.docs.isNotEmpty
        ? totalScore / liftsSnap.docs.length
        : 0.0;

    final totalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workout_totals')
        .doc(widget.workoutIndex.toString());

    await totalsRef.update({
      'workoutWorkload': totalWorkload,
      'workoutScore': avgScore,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
      body: ListView.builder(
        itemCount: workout.lifts.length,
        itemBuilder: (context, index) {
          final lift = workout.lifts[index];
          final repCtrls = _repCtrls[index] ?? [];
          final weightCtrls = _weightCtrls[index] ?? [];
          final prev = _prevEntries[index] ?? [];

          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text(lift.name),
              children: [
                ...List.generate(lift.sets, (set) {
                  final prevEntry = set < prev.length ? prev[set] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text('Set ${set + 1}'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: repCtrls[set],
                            decoration:
                                const InputDecoration(labelText: 'Reps'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _saveLift(index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: weightCtrls[set],
                            decoration:
                                const InputDecoration(labelText: 'Weight'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _saveLift(index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (prevEntry != null)
                          Text(
                              'Prev ${prevEntry['reps']} x ${prevEntry['weight'] ?? 0}'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
