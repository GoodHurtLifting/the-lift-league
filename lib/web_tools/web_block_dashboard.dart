import 'package:flutter/material.dart';
import '../models/custom_block_models.dart';
import 'web_workout_log.dart';
import 'web_custom_block_service.dart';
import 'auth_utils.dart';
import 'web_sign_in_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

  @override
  void initState() {
    super.initState();
    _runId = widget.runId;
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
      setState(() => _runId = runId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.block.name),
      ),
      body: ListView.builder(
        itemCount: widget.block.workouts.length,
        itemBuilder: (context, index) {
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
