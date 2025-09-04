import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/services/db_service.dart'
    show DBService, SCORE_TYPE_BODYWEIGHT, SCORE_TYPE_MULTIPLIER;
import 'package:lift_league/widgets/confirmation_dialog.dart';
import 'package:lift_league/services/lift_catalog_service.dart';


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
  List<Map<String, dynamic>> _liftMeta = [];

  void _applyEditsSoon() {
    _applyDebounce?.cancel();
    _applyDebounce = Timer(const Duration(milliseconds: 400), () {
      // Drop any lifts lacking a catalog selection to enforce catalog-only entries.
      final filteredLifts = <LiftDraft>[];
      final filteredMeta = <Map<String, dynamic>>[];
      for (int i = 0; i < widget.workout.lifts.length; i++) {
        if (i < _liftMeta.length && _liftMeta[i]['liftId'] != null) {
          filteredLifts.add(widget.workout.lifts[i]);
          filteredMeta.add(_liftMeta[i]);
        }
      }

      widget.workout.lifts
        ..clear()
        ..addAll(filteredLifts);
      _liftMeta = filteredMeta;

      DBService().syncBuilderEdits(
        customBlockId: widget.customBlockId,
        blockInstanceId: widget.activeBlockInstanceId,
        dayIndex: widget.workout.dayIndex,
        lifts: widget.workout.lifts,
        meta: _liftMeta,
      );
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
    if (widget.activeBlockInstanceId == null) {
      _nameController.text = widget.workout.name;
      _liftMeta = widget.workout.lifts
          .map((l) => {
                'liftId': null,
                'repScheme': '${l.sets}x${l.repsPerSet}',
                'scoreType': l.isBodyweight
                    ? SCORE_TYPE_BODYWEIGHT
                    : SCORE_TYPE_MULTIPLIER,
                'youtubeUrl': '',
                'referenceLiftId': null,
                'percentOfReference': null,
              })
          .toList();
      setState(() {});
      return;
    }

    final inst =
        await DBService().getWorkoutInstanceById(widget.workout.id);
    if (!mounted || inst == null) return;

    final lifts =
        await DBService().getLiftsForWorkoutInstance(widget.workout.id);
    if (!mounted) return;

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
              position: (m['position'] as num?)?.toInt() ?? 0,
            )));
      _liftMeta = lifts
          .map((m) => {
                'liftId': (m['liftId'] as num?)?.toInt(),
                'repScheme': (m['repScheme'] as String?) ??
                    '${m['sets'] ?? 0}x${m['repsPerSet'] ?? 0}',
                'scoreType': (m['scoreType'] as num?)?.toInt() ??
                    SCORE_TYPE_MULTIPLIER,
                'youtubeUrl': m['youtubeUrl']?.toString() ?? '',
                'referenceLiftId':
                    (m['referenceLiftId'] as num?)?.toInt(),
                'percentOfReference':
                    (m['percentOfReference'] as num?)?.toDouble(),
              })
          .toList();
    });
    _nameController.text = widget.workout.name;
  }

  Future<Map<String, Object?>?> _pickFromCatalog(BuildContext context) async {
    // Seed once (no-op if already populated)
    await LiftCatalogService.instance.ensureSeeded();

    final groups = await LiftCatalogService.instance.getGroups();

    String? group;
    String search = '';
    bool? bw;
    bool? dbb;

    Future<List<Map<String, Object?>>> _fetch() {
      return LiftCatalogService.instance.query(
        group: group,
        queryText: search.isEmpty ? null : search,
        bodyweightCapable: bw,
        dumbbellCapable: dbb,
        limit: 200,
      );
    }

    return showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String?>(
                      value: group,
                      isExpanded: true,
                      hint: const Text('Muscle Group'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...groups.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
                      ],
                      onChanged: (v) => setSheetState(() => group = v),
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Search'),
                      onChanged: (v) => setSheetState(() => search = v),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bodyweight-capable'),
                            value: bw ?? false,
                            onChanged: (v) => setSheetState(() => bw = v == true ? true : null),
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Dumbbell-capable'),
                            value: dbb ?? false,
                            onChanged: (v) => setSheetState(() => dbb = v == true ? true : null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: FutureBuilder<List<Map<String, Object?>>>(
                        future: _fetch(),
                        builder: (ctx, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final results = snap.data ?? const [];
                          if (results.isEmpty) {
                            return const Center(child: Text('No lifts match your filters.'));
                          }
                          return ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (ctx, i) {
                              final r = results[i];
                              final name = (r['name'] ?? '').toString();
                              final grp  = (r['primaryGroup'] ?? '').toString();
                              return ListTile(
                                title: Text(name),
                                subtitle: Text(grp),
                                onTap: () => Navigator.of(sheetCtx).pop(r),
                              );
                            },
                          );
                        },
                      ),
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


  void _showAddLiftSheet() {
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    bool isBodyweight = false;
    bool isDumbbellLift = false;
    Map<String, Object?>? selected;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool isSaving = false;
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
                    ListTile(
                      title: Text(selected?['name']?.toString() ?? 'Select lift'),
                      trailing: const Icon(Icons.search),
                      onTap: () async {
                        final res = await _pickFromCatalog(ctx);
                        if (res != null) {
                          setLocalState(() => selected = res);
                        }
                      },
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
                      onPressed: isSaving || selected == null
                          ? null
                          : () async {
                              final idVal = selected?['catalogId'];
                              if (idVal == null) return;
                              final liftId = (idVal as num).toInt();
                              final name = selected?['name']?.toString() ?? '';
                              final sets = int.tryParse(setsCtrl.text) ?? 3;
                              final reps = int.tryParse(repsCtrl.text) ?? 10;
                              final repText = '${sets}x${reps}';

                              final newLift = LiftDraft(
                                name: name,
                                sets: sets,
                                repsPerSet: reps,
                                multiplier: 0,
                                isBodyweight: isBodyweight,
                                isDumbbellLift: isDumbbellLift,
                                position: widget.workout.lifts.length,
                              );

                              final sheetNav = Navigator.of(ctx);
                              FocusScope.of(ctx).unfocus();

                              setLocalState(() => isSaving = true);
                              try {
                                final scoreType = isBodyweight
                                    ? SCORE_TYPE_BODYWEIGHT
                                    : SCORE_TYPE_MULTIPLIER;
                                await DBService.instance.addLiftToCustomWorkout(
                                  customWorkoutId: widget.workout.id,
                                  liftCatalogId: liftId,
                                  repSchemeText: repText,
                                  sets: sets,
                                  repsPerSet: reps,
                                  isBodyweight: isBodyweight ? 1 : 0,
                                  isDumbbell: isDumbbellLift ? 1 : 0,
                                  scoreType:
                                      isBodyweight ? 'bodyweight' : 'multiplier',
                                );
                                if (mounted) {
                                  setState(() {
                                    widget.workout.lifts.add(newLift);
                                    _liftMeta.add({
                                      'liftId': liftId,
                                      'repScheme': repText,
                                      'scoreType': scoreType,
                                    });
                                  });
                                }
                                _applyEditsSoon();
                                setLocalState(() => isSaving = false);
                                sheetNav.pop();
                              } catch (_) {
                                if (!mounted) return;
                                setLocalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Failed to save lift')),
                                );
                              }
                            },
                      child: isSaving
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
    final setsCtrl = TextEditingController(text: lift.sets.toString());
    final repsCtrl = TextEditingController(text: lift.repsPerSet.toString());

    bool isBodyweight = lift.isBodyweight;
    bool isDumbbellLift = lift.isDumbbellLift;
    Map<String, Object?> selected = {
      'catalogId': _liftMeta[index]['liftId'],
      'name': _liftMeta[index]['liftId'] != null ? lift.name : null,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
                    ListTile(
                      title: Text(selected['name']?.toString() ?? 'Select lift'),
                      trailing: const Icon(Icons.search),
                      onTap: () async {
                        final res = await _pickFromCatalog(ctx);
                        if (res != null) {
                          setLocalState(() => selected = res);
                        }
                      },
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
                      onPressed: _isSaving || selected['catalogId'] == null
                          ? null
                          : () async {
                              final sets =
                                  int.tryParse(setsCtrl.text) ?? lift.sets;
                              final reps =
                                  int.tryParse(repsCtrl.text) ?? lift.repsPerSet;
                              final repText = '${sets}x${reps}';

                              setLocalState(() => _isSaving = true);

                              final scoreType = isBodyweight
                                  ? SCORE_TYPE_BODYWEIGHT
                                  : SCORE_TYPE_MULTIPLIER;
                              lift
                                ..name = selected['name'] as String
                                ..sets = sets
                                ..repsPerSet = reps
                                ..isBodyweight = isBodyweight
                                ..isDumbbellLift = isDumbbellLift;
                              _liftMeta[index] = {
                                'liftId': (selected['catalogId'] as num).toInt(),
                                'repScheme': repText,
                                'scoreType': scoreType,
                              };
                              _applyEditsSoon();
                              setLocalState(() => _isSaving = false);
                              Navigator.of(ctx).pop();
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
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Remove Lift?',
                                message:
                                    'Deletes this lift from all workouts in this block and erases logged sets. This cannot be undone.',
                              );
                              if (!ok) return;
                              setLocalState(() => _isSaving = true);
                              widget.workout.lifts.removeAt(index);
                              _liftMeta.removeAt(index);
                              _applyEditsSoon();
                              setLocalState(() => _isSaving = false);
                              if (ctx.mounted) Navigator.of(ctx).pop();
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
