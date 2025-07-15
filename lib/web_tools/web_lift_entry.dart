import 'package:flutter/material.dart';
import '../models/custom_block_models.dart';

/// Displays an editable table for logging a single lift within a web workout.
class WebLiftEntry extends StatefulWidget {
  /// Index of the lift within the workout. Used for callbacks.
  final int liftIndex;

  /// Lift template containing name, set count and reps per set.
  final LiftDraft lift;

  /// Previous entries for this lift from the most recent run. Each map should
  /// contain `reps` and `weight` keys.
  final List<Map<String, dynamic>> previousEntries;

  /// A recommended weight to display instead of previous weight when provided.
  final double? recommendedWeight;

  /// Callback triggered whenever a field changes. Returns lists of reps and
  /// weights strings corresponding to each set.
  final void Function(List<String> reps, List<String> weights)? onChanged;

  const WebLiftEntry({
    super.key,
    required this.liftIndex,
    required this.lift,
    this.previousEntries = const [],
    this.recommendedWeight,
    this.onChanged,
  });

  @override
  State<WebLiftEntry> createState() => _WebLiftEntryState();
}

class _WebLiftEntryState extends State<WebLiftEntry> {
  late final List<TextEditingController> _repCtrls;
  late final List<TextEditingController> _weightCtrls;

  @override
  void initState() {
    super.initState();
    _repCtrls =
        List.generate(widget.lift.sets, (_) => TextEditingController());
    _weightCtrls =
        List.generate(widget.lift.sets, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _repCtrls) c.dispose();
    for (final c in _weightCtrls) c.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged?.call(
      _repCtrls.map((c) => c.text).toList(),
      _weightCtrls.map((c) => c.text).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repScheme = '${widget.lift.sets} x ${widget.lift.repsPerSet}';
    final prev = widget.previousEntries;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(widget.lift.name),
        subtitle: Text(repScheme),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(0.4),
              3: FlexColumnWidth(1.4),
              4: FlexColumnWidth(0.05),
              5: FlexColumnWidth(1),
              6: FlexColumnWidth(0.4),
              7: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Reps', textAlign: TextAlign.center),
                  ),
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Weight', textAlign: TextAlign.center),
                  ),
                  const SizedBox.shrink(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Prev Reps', textAlign: TextAlign.center),
                  ),
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.recommendedWeight != null
                          ? 'Recommended'
                          : 'Prev Weight',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              ...List.generate(widget.lift.sets, (set) {
                final prevEntry = set < prev.length ? prev[set] : null;
                final prevReps = prevEntry != null
                    ? (prevEntry['reps']?.toString() ?? '-')
                    : '-';
                final prevWeightNum = prevEntry != null
                    ? (prevEntry['weight'] as num?)?.toDouble()
                    : null;
                String prevWeight = '-';
                if (prevWeightNum != null && prevWeightNum > 0) {
                  prevWeight = prevWeightNum % 1 == 0
                      ? prevWeightNum.toInt().toString()
                      : prevWeightNum.toStringAsFixed(1);
                }

                final recWeight = widget.recommendedWeight;
                final recText =
                    recWeight != null ? recWeight.toStringAsFixed(0) : prevWeight;

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Set ${set + 1}',
                          textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _repCtrls[set],
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
                        controller: _weightCtrls[set],
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _notifyChanged(),
                        decoration: const InputDecoration(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox.shrink(),
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
            ],
          ),
        ],
      ),
    );
  }
}
