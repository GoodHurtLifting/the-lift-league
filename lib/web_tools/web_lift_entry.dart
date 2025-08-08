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
  bool _initialized = false;

  void _removeInitialZero() {
    if (_initialized) return;
    for (final c in widget.repControllers) {
      if (c.text == '0') {
        c.text = '';
      }
    }
    _initialized = true;
  }

  void _notifyChanged() {
    setState(() {});
    widget.onChanged?.call(
      widget.repControllers.map((c) => c.text).toList(),
      widget.weightControllers.map((c) => c.text).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _removeInitialZero();
    print('Rendering WebLiftEntry for ${widget.lift.name}');
    print('previousEntries: ${widget.previousEntries}');
    final repScheme = '${widget.lift.sets} x ${widget.lift.repsPerSet}';
    final prev = widget.previousEntries;

    // Calculate previous totals if data exists
    final prevReps = prev.isNotEmpty
        ? getLiftRepsFromDb(prev, isDumbbellLift: widget.lift.isDumbbellLift)
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
            scoreType: widget.lift.isBodyweight ? 'bodyweight' : 'multiplier',
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
      scoreType: widget.lift.isBodyweight ? 'bodyweight' : 'multiplier',
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
              0: FlexColumnWidth(1.2),   // Set
              1: FlexColumnWidth(1.2),   // Reps
              2: FlexColumnWidth(0.4),   // x
              3: FlexColumnWidth(1.4),   // Weight
              4: FixedColumnWidth(1),    // Divider
              5: FlexColumnWidth(1.2),   // Prev Reps
              6: FlexColumnWidth(1.2),   // Prev Weight (or Score in last row)
            },
            children: [
              // Header row (7 columns)
              TableRow(
                children: [
                  const SizedBox.shrink(), // Set
                  const Padding(
                    padding: EdgeInsets.all(.0),
                    child: Text(
                      'Reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox.shrink(), // x
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
              // Sets rows (7 columns)
              ...List.generate(widget.lift.sets, (set) {
                final prevEntry = set < prev.length ? prev[set] : null;
                final prevReps = prevEntry != null ? (prevEntry['reps']?.toString() ?? '') : '';
                final prevWeightNum = prevEntry != null ? (prevEntry['weight'] as num?)?.toDouble() : null;
                String prevWeight = '';
                if (prevWeightNum != null && prevWeightNum > 0) {
                  prevWeight = prevWeightNum % 1 == 0
                      ? prevWeightNum.toInt().toString()
                      : prevWeightNum.toStringAsFixed(1);
                }

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
                      color: Colors.grey.shade300,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(prevReps, textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(prevWeight, textAlign: TextAlign.center),
                    ),
                  ],
                );
              }),
              // Totals row (7 columns)
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Total', textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(liftReps.toString(), textAlign: TextAlign.center),
                  ),
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(workloadText, textAlign: TextAlign.center),
                  ),
                  Container(
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(prev.isEmpty ? '' : prevReps.toString(), textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(prevWorkloadText, textAlign: TextAlign.center),
                  ),
                ],
              ),
              // Score row (7 columns, last two cells: current and previous score)
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
                    color: Colors.grey.shade300,
                  ),
                  // Leave this cell blank for visual spacing
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
          )
        ],
      ),
    );
  }
}
