import 'package:flutter/material.dart';
import '../models/custom_block_models.dart';
import '../services/calculations.dart';

/// Displays an editable table for logging a single lift within a web workout.
class WebLiftEntry extends StatefulWidget {
  /// Index of the lift within the workout. Used for callbacks.
  final int liftIndex;

  /// Lift template containing name, set count and reps per set.
  final LiftDraft lift;

  /// Previous entries for this lift from the most recent run. Each map should
  /// contain `reps` and `weight` keys.
  final List<Map<String, dynamic>> previousEntries;

  /// Controllers for reps input fields, one per set.
  final List<TextEditingController> repControllers;

  /// Controllers for weight input fields, one per set.
  final List<TextEditingController> weightControllers;


  /// Callback triggered whenever a field changes. Returns lists of reps and
  /// weights strings corresponding to each set.
  final void Function(List<String> reps, List<String> weights)? onChanged;

  const WebLiftEntry({
    super.key,
    required this.liftIndex,
    required this.lift,
    required this.repControllers,
    required this.weightControllers,
    this.previousEntries = const [],
    this.onChanged,
  });

  @override
  State<WebLiftEntry> createState() => _WebLiftEntryState();
}

class _WebLiftEntryState extends State<WebLiftEntry> {
  void _notifyChanged() {
    setState(() {});
    widget.onChanged?.call(
      widget.repControllers.map((c) => c.text).toList(),
      widget.weightControllers.map((c) => c.text).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Rendering WebLiftEntry for ${widget.lift.name}');
    print('previousEntries: ${widget.previousEntries}');
    final repScheme = '${widget.lift.sets} x ${widget.lift.repsPerSet}';
    final prev = widget.previousEntries;

    // Calculate previous totals if data exists
    final prevReps = prev.isNotEmpty
        ? getLiftRepsFromDb(prev,
            isDumbbellLift: widget.lift.isDumbbellLift)
        : 0;
    final prevWorkload = prev.isNotEmpty
        ? getLiftWorkloadFromDb(prev,
            isDumbbellLift: widget.lift.isDumbbellLift)
        : 0.0;
    final prevScore = prev.isNotEmpty
        ? calculateLiftScoreFromEntries(
            prev,
            widget.lift.multiplier,
            isDumbbellLift: widget.lift.isDumbbellLift,
            scoreType: widget.lift.isBodyweight ? 'bodyweight' : 'default',
          )
        : 0.0;
    final prevWorkloadText = prev.isNotEmpty
        ? (prevWorkload % 1 == 0
            ? prevWorkload.toInt().toString()
            : prevWorkload.toStringAsFixed(1))
        : '';
    final prevScoreText = prev.isNotEmpty
        ? (prevScore % 1 == 0
            ? prevScore.toInt().toString()
            : prevScore.toStringAsFixed(1))
        : '';

    final liftReps = getLiftReps(widget.repControllers,
        isDumbbellLift: widget.lift.isDumbbellLift);
    final liftWorkload = getLiftWorkload(
      widget.repControllers,
      widget.weightControllers,
      isDumbbellLift: widget.lift.isDumbbellLift,
    );
    final liftScore = getLiftScore(
      widget.repControllers,
      widget.weightControllers,
      widget.lift.multiplier,
      isDumbbellLift: widget.lift.isDumbbellLift,
      scoreType: widget.lift.isBodyweight ? 'bodyweight' : 'default',
    );
    final workloadText = liftWorkload % 1 == 0
        ? liftWorkload.toInt().toString()
        : liftWorkload.toStringAsFixed(1);
    final scoreText = liftScore % 1 == 0
        ? liftScore.toInt().toString()
        : liftScore.toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(widget.lift.name),
        subtitle: Text(repScheme),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(0.4),
              3: FlexColumnWidth(1.4),
              4: FixedColumnWidth(1),
              5: FlexColumnWidth(1),
              6: FlexColumnWidth(0.4),
              7: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(.0),
                    child: Text(
                      'Reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Weight',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Weight',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              ...List.generate(widget.lift.sets, (set) {
                final prevEntry = set < prev.length ? prev[set] : null;
                if (prevEntry != null) {
                  print('Prev data for ${widget.lift.name} set ${set + 1}: '
                      '${prevEntry['reps']}x${prevEntry['weight']}');
                }
                final prevReps =
                    prevEntry != null ? (prevEntry['reps']?.toString() ?? '') : '';
                final prevWeightNum =
                    prevEntry != null ? (prevEntry['weight'] as num?)?.toDouble() : null;
                String prevWeight = '';
                if (prevWeightNum != null && prevWeightNum > 0) {
                  prevWeight = prevWeightNum % 1 == 0
                      ? prevWeightNum.toInt().toString()
                      : prevWeightNum.toStringAsFixed(1);
                }

                final recText = prevWeight;

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Set ${set + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: widget.repControllers[set],
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _notifyChanged(),
                        decoration: const InputDecoration(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('x', textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: widget.weightControllers[set],
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _notifyChanged(),
                        decoration: const InputDecoration(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: double.infinity,
                      color: Colors.grey.shade300,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(prevReps, textAlign: TextAlign.center),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('x', textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(recText, textAlign: TextAlign.center),
                    ),
                  ],
                );
              }),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Total', textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:
                        Text(liftReps.toString(), textAlign: TextAlign.center),
                  ),
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:
                        Text(workloadText, textAlign: TextAlign.center),
                  ),
                  Container(
                    width: 1,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      prev.isEmpty ? '' : prevReps.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('x', textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(prevWorkloadText, textAlign: TextAlign.center),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Score',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      scoreText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      prevScoreText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
