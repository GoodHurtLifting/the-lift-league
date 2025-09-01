import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/data/lift_data.dart';
import 'package:lift_league/services/score_multiplier_service.dart';
import 'package:lift_league/services/db_service.dart';

class WorkoutBuilder extends StatefulWidget {
  final WorkoutDraft workout;
  final List<WorkoutDraft> allWorkouts;
  final int currentIndex;
  final ValueChanged<int> onSelectWorkout;
  final Future<void> Function() onComplete; // instead of VoidCallback
  final bool isLast;
  final bool showDumbbellOption;
  final int customBlockId;
  final int? activeBlockInstanceId;
  final VoidCallback? onPreviewSchedule;
  const WorkoutBuilder({
    super.key,
    required this.workout,
    required this.allWorkouts,
    required this.currentIndex,
    required this.onSelectWorkout,
    required this.onComplete,
    required this.customBlockId,
    this.activeBlockInstanceId,
    this.isLast = false,
    this.showDumbbellOption = false,
    this.onPreviewSchedule,
  });

  @override
  State<WorkoutBuilder> createState() => _WorkoutBuilderState();
}

class _WorkoutBuilderState extends State<WorkoutBuilder> {
  late TextEditingController _nameController;

  Timer? _applyDebounce;

  void _applyEditsSoon() {
    final instanceId = widget.activeBlockInstanceId;
    if (instanceId == null) return;
    _applyDebounce?.cancel();
    _applyDebounce = Timer(const Duration(milliseconds: 400), () async {
      await DBService()
          .applyCustomBlockEdits(widget.customBlockId, instanceId);
      // Optional: log
      // print('[WorkoutBuilder] Applied edits to instance=$instanceId');
    });
  }


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
    _loadWorkoutFromDb();
  }

  @override
  void didUpdateWidget(covariant WorkoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout.id != widget.workout.id) {
      _loadWorkoutFromDb();
    }
    if (oldWidget.workout != widget.workout) {
      _nameController.text = widget.workout.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutFromDb() async {
    final inst =
        await DBService().getWorkoutInstanceById(widget.workout.id);
    if (inst == null || !mounted) return;
    final lifts =
        await DBService().getLiftsForWorkoutInstance(widget.workout.id);
    setState(() {
      widget.workout
        ..name = (inst['workoutName'] as String? ?? widget.workout.name)
        ..dayIndex = (inst['dayIndex'] as int? ?? widget.workout.dayIndex)
        ..isPersisted = true;
      widget.workout.lifts
        ..clear()
        ..addAll(lifts.map((m) => LiftDraft(
              id: (m['liftInstanceId'] as num?)?.toInt(),
              name: (m['name'] as String?) ?? '',
              sets: (m['sets'] as num?)?.toInt() ?? 0,
              repsPerSet: (m['repsPerSet'] as num?)?.toInt() ?? 0,
              multiplier:
                  ((m['scoreMultiplier'] as num?) ?? 0).toDouble(),
              isBodyweight: (m['isBodyweight'] as num?)?.toInt() == 1,
              isDumbbellLift:
                  (m['isDumbbellLift'] as num?)?.toInt() == 1,
            )));
    });
    _nameController.text = widget.workout.name;
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

        bool _isSaving = false;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
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
                        if (text.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return liftNames.where(
                          (n) =>
                              n.toLowerCase().contains(text.text.toLowerCase()),
                        );
                      },
                      fieldViewBuilder: (context, controller, focus, onSubmit) {
                        return TextField(
                          controller: controller,
                          focusNode: focus,
                          decoration:
                              const InputDecoration(labelText: 'Lift name'),
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
                            decoration:
                                const InputDecoration(labelText: 'Sets'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: repsCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Reps'),
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
                      onPressed: _isSaving
                          ? null
                          : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final sets = int.tryParse(setsCtrl.text) ?? 3;
                        final reps = int.tryParse(repsCtrl.text) ?? 10;

                        // Get multiplier (should be PURE; if it mutates inputs, we'll catch below)
                        final multiplier =
                        ScoreMultiplierService().getMultiplier(
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
                        print(
                            '[AddLift] BEFORE add → ${newLift.name}: ${newLift.sets}x${newLift.repsPerSet} (BW=$isBodyweight, DB=$isDumbbellLift)');

                        final sheetNav = Navigator.of(ctx);
                        FocusScope.of(ctx).unfocus();

                        setLocalState(() => _isSaving = true);
                        try {
                          await DBService().addLiftAcrossSlot(
                            workoutInstanceId: widget.workout.id,
                            lift: newLift,
                            insertAt: widget.workout.lifts.length,
                          );
                          await _loadWorkoutFromDb();
                          _applyEditsSoon();
                          setLocalState(() => _isSaving = false);
                          sheetNav.pop();
                        } catch (e) {
                          if (!mounted) return;
                          setLocalState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to save lift')),
                          );
                        }
                      },
                      child: _isSaving
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Save'),
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

  void _showEditLiftSheet(int index) {
    final lift = widget.workout.lifts[index];
    final nameController = TextEditingController(text: lift.name);
    final setsCtrl = TextEditingController(text: lift.sets.toString());
    final repsCtrl = TextEditingController(text: lift.repsPerSet.toString());

    bool isBodyweight = lift.isBodyweight;
    bool isDumbbellLift = lift.isDumbbellLift;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final liftNames = liftDataList
            .map((e) => e['liftName'] as String)
            .toSet()
            .toList()
          ..sort();

        bool _isSaving = false;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue text) {
                        if (text.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return liftNames.where(
                          (n) =>
                              n.toLowerCase().contains(text.text.toLowerCase()),
                        );
                      },
                      fieldViewBuilder: (context, controller, focus, onSubmit) {
                        controller.text = nameController.text;
                        return TextField(
                          controller: controller,
                          focusNode: focus,
                          decoration:
                              const InputDecoration(labelText: 'Lift name'),
                          onChanged: (v) => nameController.text = v,
                        );
                      },
                      onSelected: (v) => nameController.text = v,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Sets'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: repsCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Reps'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
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
                      onPressed: _isSaving
                          ? null
                          : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final sets = int.tryParse(setsCtrl.text) ?? lift.sets;
                        final reps =
                            int.tryParse(repsCtrl.text) ?? lift.repsPerSet;

                        final multiplier =
                        ScoreMultiplierService().getMultiplier(
                          sets: sets,
                          repsPerSet: reps,
                          isBodyweight: isBodyweight,
                        );

                        final liftId = widget.workout.lifts[index].id!;
                        final sheetNav = Navigator.of(ctx);
                        FocusScope.of(ctx).unfocus();

                        setLocalState(() => _isSaving = true);
                        try {
                          await DBService().updateLiftAcrossSlot(
                            workoutInstanceId: widget.workout.id,
                            liftInstanceId: liftId,
                            name: name,
                            sets: sets,
                            repsPerSet: reps,
                            scoreMultiplier: multiplier,
                            isBodyweight: isBodyweight,
                            isDumbbellLift: isDumbbellLift,
                          );
                          await _loadWorkoutFromDb();
                          _applyEditsSoon();
                          setLocalState(() => _isSaving = false);
                          sheetNav.pop();
                        } catch (e) {
                          if (!mounted) return;
                          setLocalState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to save lift')),
                          );
                        }
                      },
                      child: _isSaving
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Save'),
                    ),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                        final liftId = widget.workout.lifts[index].id!;

                        setLocalState(() => _isSaving = true);
                        try {
                          await DBService().removeLiftAcrossSlot(
                            workoutInstanceId: widget.workout.id,
                            liftInstanceId: liftId,
                          );
                          await _loadWorkoutFromDb();
                          _applyEditsSoon();
                          setLocalState(() => _isSaving = false);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          if (!mounted) return;
                          setLocalState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to delete lift'),
                            ),
                          );
                        }
                      },
                      child: const Text('Delete'),
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
            onChanged: (v) async {
              widget.workout.name = v;
              try {
                await DBService().updateWorkoutNameAcrossSlot(
                  widget.workout.id,
                  v,
                );
                _applyEditsSoon();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to rename workout'),
                  ),
                );
              }
            },
          ),
        ),
        if (widget.allWorkouts.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.allWorkouts.length, (i) {
                final name = widget.allWorkouts[i].name.isNotEmpty
                    ? widget.allWorkouts[i].name
                    : 'Assemble Workout ${i + 1}';
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: vertical icon rail
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Add Lift (plus)
                    IconButton(
                      tooltip: 'Add lift',
                      icon: const Icon(Icons.add),
                      onPressed: _showAddLiftSheet,
                      iconSize: 28,
                    ),
                    const SizedBox(height: 12),

                    // Preview Schedule (eyeball)
                    IconButton(
                      tooltip: 'Preview schedule',
                      icon: const Icon(Icons.visibility),
                      onPressed: widget.onPreviewSchedule, // <- from wizard
                      iconSize: 26,
                    ),
                    const SizedBox(height: 12),

                    // Next Workout OR Build Block (icon-only)
                    IconButton(
                      tooltip: widget.isLast ? 'Build block' : 'Next workout',
                      icon: Icon(widget.isLast ? Icons.construction : Icons.arrow_forward),
                      onPressed: () async {
                        if (widget.workout.name != _nameController.text) {
                          widget.workout.name = _nameController.text;
                          try {
                            await DBService().updateWorkoutNameAcrossSlot(
                              widget.workout.id,
                              widget.workout.name,
                            );
                          } catch (_) {}
                        }
                        _applyEditsSoon();
                        await widget.onComplete();
                      },
                      iconSize: 28,
                    ),
                  ],
                ),
              ),

              // RIGHT: centered list, multiplier removed
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: widget.workout.lifts.length,
                      itemBuilder: (context, index) {
                        final lift = widget.workout.lifts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            title: Text(
                              'Lift ${index + 1}: ${lift.name}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${lift.sets} x ${lift.repsPerSet}',
                              textAlign: TextAlign.center,
                            ),
                            // ⛔️ trailing removed to hide multiplier
                            onLongPress: () => _showEditLiftSheet(index),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
