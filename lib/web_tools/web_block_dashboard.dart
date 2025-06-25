import 'dart:core';

import 'package:flutter/material.dart';
import '../models/custom_block_models.dart';
import 'web_workout_log.dart';
import 'web_custom_block_service.dart';
import 'auth_utils.dart';
import 'web_sign_in_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebBlockDashboard extends StatefulWidget {
  final CustomBlock block;
  final String? runId;
  const WebBlockDashboard({super.key, required this.block, this.runId});

  @override
  State<WebBlockDashboard> createState() => _WebBlockDashboardState();
}

class _WebBlockDashboardState extends State<WebBlockDashboard> {
  String? _runId;
  bool _starting = false;
  bool _loadingRuns = true;
  final List<int> _runNumbers = [];
  final Map<int, String> _runIdMap = {}; // runNumber -> runId
  int _currentRunNumber = 1;
  final Map<String, double> _bestScoresByType = {};
  double _blockScore = 0.0;

  @override
  void initState() {
    super.initState();
    _runId = widget.runId;
    _loadRuns();
  }

  Future<void> _startRun() async {
    if (_starting) return;
    if (widget.block.workouts.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null) {
      final signedIn = await showWebSignInDialog(context);
      if (!signedIn) return;
    }
    setState(() => _starting = true);
    try {
      final runId = await WebCustomBlockService().startBlockRun(widget.block);
      if (!mounted) return;
      _runId = runId;
      await _loadRuns();
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Block started')));
    } on FirebaseException catch (e) {
      final reauthed = await promptReAuthIfNeeded(context, e);
      if (reauthed) {
        await _startRun();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
        }
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _confirmDeleteRun(int runNumber) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Run?'),
        content: Text('Delete run $runNumber and all data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteRun(runNumber);
    }
  }

  Future<void> _loadRuns() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .where('blockName', isEqualTo: widget.block.name)
        .orderBy('runNumber')
        .get();

    _runNumbers.clear();
    _runIdMap.clear();
    for (final doc in snap.docs) {
      final data = doc.data();
      final runNumber = (data['runNumber'] is int)
          ? data['runNumber'] as int
          : int.tryParse(data['runNumber'].toString()) ?? 1;
      _runNumbers.add(runNumber);
      _runIdMap[runNumber] = doc.id;
      if (_runId == null) {
        _runId = doc.id;
        _currentRunNumber = runNumber;
      } else if (doc.id == _runId) {
        _currentRunNumber = runNumber;
      }
    }

    _loadingRuns = false;
    await _loadTotals();
    if (mounted) setState(() {});
  }

  Future<void> _loadTotals() async {
    _bestScoresByType.clear();
    _blockScore = 0.0;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _runId == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(_runId)
        .collection('workout_totals')
        .get();

    for (final doc in snap.docs) {
      final index = int.tryParse(doc.id) ?? 0;
      if (index >= widget.block.workouts.length) continue;
      final name = widget.block.workouts[index].name;
      final score = (doc.data()['workoutScore'] as num?)?.toDouble() ?? 0.0;

      if (!_bestScoresByType.containsKey(name) || score > _bestScoresByType[name]!) {
        _bestScoresByType[name] = score;
      }
    }
    _blockScore = _bestScoresByType.values.fold(0.0, (a, b) => a + b);
  }

  Future<void> _deleteRun(int runNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    final runId = _runIdMap[runNumber];
    if (user == null || runId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('block_runs')
        .doc(runId)
        .delete();

    if (_runId == runId) {
      _runId = null;
    }
    await _loadRuns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.block.name),
        actions: [
          if (_runId != null)
            IconButton(
              onPressed: _startRun,
              icon: const Icon(Icons.replay),
            ),
        ],
      ),
      body: _loadingRuns
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: widget.block.workouts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                if (_runNumbers.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _runNumbers.map((n) {
                        final isCurrent = n == _currentRunNumber;
                        return GestureDetector(
                          onTap: () {
                            if (n != _currentRunNumber) {
                              _runId = _runIdMap[n];
                              _currentRunNumber = n;
                              _loadTotals();
                              setState(() {});
                            }
                          },
                          onLongPress: () => _confirmDeleteRun(n),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.red : Colors.grey[800],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$n',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ..._bestScoresByType.entries.map(
                  (e) => Text('Best ${e.key}: ${e.value.toStringAsFixed(1)}'),
                ),
                Text(
                  'Block Total: ${_blockScore.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            );
          }
          final workout = widget.block.workouts[index];
          final week = index ~/ widget.block.daysPerWeek + 1;
          final day = index % widget.block.daysPerWeek + 1;
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text('Week $week - Day $day: ${workout.name}'),
              children: [
                ...workout.lifts.map(
                  (l) => ListTile(
                    title: Text(l.name),
                    subtitle: Text('${l.sets} x ${l.repsPerSet}'),
                  ),
                ),
                if (_runId != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WebWorkoutLog(
                              runId: _runId!,
                              workoutIndex: index,
                              block: widget.block,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Log Workout'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _runId == null
          ? FloatingActionButton.extended(
              onPressed: _startRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Block'),
            )
          : null,
    );
  }
}
