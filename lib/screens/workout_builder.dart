import 'package:flutter/material.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/data/lift_data.dart';
import 'package:lift_league/services/score_multiplier_service.dart';

class WorkoutBuilder extends StatefulWidget {
  final WorkoutDraft workout;
  final List<WorkoutDraft> allWorkouts;
  final int currentIndex;
  final ValueChanged<int> onSelectWorkout;
  final VoidCallback onComplete;
  final bool isLast;
  final bool showDumbbellOption;
  const WorkoutBuilder({
    super.key,
    required this.workout,
    required this.allWorkouts,
    required this.currentIndex,
    required this.onSelectWorkout,
    required this.onComplete,
    this.isLast = false,
    this.showDumbbellOption = false,
  });

  @override
  State<WorkoutBuilder> createState() => _WorkoutBuilderState();
}

class _WorkoutBuilderState extends State<WorkoutBuilder> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
  }

  @override
  void didUpdateWidget(covariant WorkoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout != widget.workout) {
      _nameController.text = widget.workout.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddLiftSheet() {
    final nameController = TextEditingController();
    final setsCtrl = TextEditingController(text: '');
    final repsCtrl = TextEditingController(text: '');

    bool isBodyweight = false;
    bool isDumbbellLift = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final liftNames = liftDataList
            .map((e) => e['liftName'] as String)
            .toSet()
            .toList()
          ..sort();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lift name
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue text) {
                        if (text.text.isEmpty) return const Iterable<String>.empty();
                        return liftNames.where(
                              (n) => n.toLowerCase().contains(text.text.toLowerCase()),
                        );
                      },
                      fieldViewBuilder: (context, controller, focus, onSubmit) {
                        return TextField(
                          controller: controller,
                          focusNode: focus,
                          decoration: const InputDecoration(labelText: 'Lift name'),
                          onChanged: (v) => nameController.text = v,
                        );
                      },
                      onSelected: (v) => nameController.text = v,
                    ),

                    // Sets / Reps
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsCtrl,
                            decoration: const InputDecoration(labelText: 'Sets'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: repsCtrl,
                            decoration: const InputDecoration(labelText: 'Reps'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    // Mutually exclusive checkboxes
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bodyweight'),
                            value: isBodyweight,
                            onChanged: (v) {
                              setLocalState(() {
                                isBodyweight = v ?? false;
                                if (isBodyweight) isDumbbellLift = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Dumbbell lift'),
                            value: isDumbbellLift,
                            onChanged: (v) {
                              setLocalState(() {
                                isDumbbellLift = v ?? false;
                                if (isDumbbellLift) isBodyweight = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final sets = int.tryParse(setsCtrl.text) ?? 3;
                        final reps = int.tryParse(repsCtrl.text) ?? 10;

                        // Get multiplier (should be PURE; if it mutates inputs, we'll catch below)
                        final multiplier = ScoreMultiplierService().getMultiplier(
                          sets: sets,
                          repsPerSet: reps,
                          isBodyweight: isBodyweight,
                        );

                        // Add lift using exactly what the user chose
                        final newLift = LiftDraft(
                          name: name,
                          sets: sets,
                          repsPerSet: reps,
                          multiplier: multiplier,
                          isBodyweight: isBodyweight,
                          isDumbbellLift: isDumbbellLift,
                        );

                        // Debug before add
                        // ignore: avoid_print
                        print('[AddLift] BEFORE add → ${newLift.name}: ${newLift.sets}x${newLift.repsPerSet} (BW=$isBodyweight, DB=$isDumbbellLift)');

                        setState(() {
                          final idx = widget.workout.lifts.length;
                          widget.workout.lifts.add(newLift);

                          // Post-add guard: force the chosen values back on, in case anything tried to normalize
                          widget.workout.lifts[idx].sets = sets;
                          widget.workout.lifts[idx].repsPerSet = reps;

                          // Debug after add
                          // ignore: avoid_print
                          print('[AddLift] AFTER add  → ${widget.workout.lifts[idx].name}: '
                              '${widget.workout.lifts[idx].sets}x${widget.workout.lifts[idx].repsPerSet}');
                        });

                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Workout name'),
            onChanged: (v) => widget.workout.name = v,
          ),
        ),
        if (widget.allWorkouts.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.allWorkouts.length, (i) {
                final name = widget.allWorkouts[i].name.isNotEmpty
                    ? widget.allWorkouts[i].name
                    : 'Workout ${i + 1}';
                final selected = i == widget.currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (_) => widget.onSelectWorkout(i),
                  ),
                );
              }),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.workout.lifts.length,
            itemBuilder: (context, index) {
              final lift = widget.workout.lifts[index];
              return ListTile(
                title: Text('Lift ${index + 1}: ${lift.name}'),
                subtitle: Text('${lift.sets} x ${lift.repsPerSet}'),
                trailing: Text(lift.multiplier.toStringAsFixed(3)),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: _showAddLiftSheet,
          child: const Text('Add Lift'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: widget.onComplete,
          child: Text(widget.isLast ? 'Build Block' : 'Next Workout'),
        ),
      ],
    );
  }
}
