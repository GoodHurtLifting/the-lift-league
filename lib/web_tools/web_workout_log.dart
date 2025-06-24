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
  final Map<int, Set<int>> _completed = {};

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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('block_runs')
          .doc(widget.runId)
          .collection('workouts')
          .doc(widget.workoutIndex.toString())
          .collection('lifts')
          .doc(i.toString())
          .get();
      final List<dynamic> completed = doc.data()?['completedSets'] ?? [];
      _completed[i] = Set<int>.from(completed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleSet(int liftIndex, int set) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final liftRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(widget.runId)
        .collection('workouts')
        .doc(widget.workoutIndex.toString())
        .collection('lifts')
        .doc(liftIndex.toString());
    final snap = await liftRef.get();
    final List<dynamic> completed = snap.data()?['completedSets'] ?? [];
    _completed[liftIndex] = Set<int>.from(completed);
    if (_completed[liftIndex]!.contains(set)) {
      await liftRef.update({
        'completedSets': FieldValue.arrayRemove([set])
      });
      _completed[liftIndex]!.remove(set);
    } else {
      await liftRef.update({
        'completedSets': FieldValue.arrayUnion([set])
      });
      _completed[liftIndex]!.add(set);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
      body: ListView.builder(
        itemCount: workout.lifts.length,
        itemBuilder: (context, index) {
          final lift = workout.lifts[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text(lift.name),
              children: List.generate(lift.sets, (set) {
                final checked = _completed[index]?.contains(set) ?? false;
                return ListTile(
                  leading: Checkbox(
                    value: checked,
                    onChanged: (_) => _toggleSet(index, set),
                  ),
                  title: Text('Set ${set + 1} - ${lift.repsPerSet} reps'),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
