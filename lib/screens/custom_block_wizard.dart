import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/screens/block_dashboard.dart';
import 'package:lift_league/screens/workout_builder.dart';
import 'package:lift_league/widgets/confirmation_dialog.dart';

class CustomBlockWizard extends StatefulWidget {
  final CustomBlock? initialBlock;
  final int customBlockId;
  final int? blockInstanceId;
  const CustomBlockWizard({
    super.key,
    required this.customBlockId,
    this.blockInstanceId,
    this.initialBlock,
  });

  @override
  State<CustomBlockWizard> createState() => _CustomBlockWizardState();
}

class _CustomBlockWizardState extends State<CustomBlockWizard> {
  final TextEditingController _nameCtrl = TextEditingController();
  String blockName = '';
  int? numWeeks;
  int? daysPerWeek;
  int? _uniqueCount;
  String _scheduleType = 'standard';
  late List<WorkoutDraft> workouts;
  int _currentStep = 0;
  int _workoutIndex = 0;
  Uint8List? _coverImageBytes;
  String? _coverImagePath;
  bool _openedEditorOnce = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialBlock != null) {
      final block = widget.initialBlock!;

      blockName = block.name;
      numWeeks = block.numWeeks;
      daysPerWeek = block.daysPerWeek;
      _scheduleType = block.scheduleType;

      final firstWeekWorkouts = _firstWeekTemplateFromBlock(block);
      _uniqueCount = firstWeekWorkouts.length;

      if (block.workouts.isNotEmpty && firstWeekWorkouts.isNotEmpty) {
        workouts = firstWeekWorkouts
            .map((w) => WorkoutDraft(
                  id: w.id,
                  dayIndex: w.dayIndex,
                  name: w.name,
                  lifts: w.lifts
                      .map((l) => LiftDraft(
                            name: l.name,
                            sets: l.sets,
                            repsPerSet: l.repsPerSet,
                            multiplier: l.multiplier,
                            isBodyweight: l.isBodyweight,
                            isDumbbellLift: l.isDumbbellLift,
                            position: l.position,
                          ))
                      .toList(),
                  isPersisted: true,
                ))
            .toList();

        _coverImagePath = block.coverImagePath;
        if (_coverImagePath != null && File(_coverImagePath!).existsSync()) {
          _coverImageBytes = File(_coverImagePath!).readAsBytesSync();
        }

        _nameCtrl.text = block.name;
        _currentStep = 5; // jump to workout step
      } else {
        workouts = [];
        _nameCtrl.text = block.name;
        _currentStep = 0;
      }
    } else {
      // New flow
      workouts = [];
      _nameCtrl.text = '';
      _currentStep = 0;
      // ensure sane defaults for new blocks
      _uniqueCount ??= 2;  // 1–7
      daysPerWeek ??= 3;  // 1..?
      numWeeks ??= 4;  // 3–6
    }

    // Keep blockName in sync with the field so step 0 can advance
    _nameCtrl.addListener(() {
      blockName = _nameCtrl.text;
    });

    // Auto-open the full-screen editor if we land on Step 5 on load (editing existing block)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentStep == 5 && workouts.isNotEmpty && !_openedEditorOnce) {
        _openedEditorOnce = true;
        _openWorkoutEditorFullscreen();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _initializeWorkouts() {
    final count = (_uniqueCount ?? 0).clamp(1, 10); // ensure at least 1
    final baseId = DateTime.now().millisecondsSinceEpoch;
    workouts = List.generate(
      count,
      (i) => WorkoutDraft(
        id: baseId + i,
        dayIndex: i,
        name: 'Workout ${i + 1}',
        lifts: [],
        isPersisted: false,
      ),
    );
  }

  List<WorkoutDraft> _firstWeekTemplateFromBlock(CustomBlock block) {
    final firstWeek = block.workouts
        .where((w) => w.dayIndex < block.daysPerWeek)
        .toList()
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    // If names could repeat within a week, keep the first occurrence by name
    final seen = <String>{};
    final uniques = <WorkoutDraft>[];
    for (final w in firstWeek) {
      final key = w.name.toLowerCase().trim();
      if (seen.add(key)) uniques.add(w);
    }
    return uniques;
  }

  List<WorkoutDraft> _firstWeekTemplateFromList(
    List<WorkoutDraft> all, {
    required int daysPerWeek,
  }) {
    final firstWeek = all.where((w) => w.dayIndex < daysPerWeek).toList()
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final seen = <String>{};
    final uniques = <WorkoutDraft>[];
    for (final w in firstWeek) {
      final key = w.name.toLowerCase().trim();
      if (seen.add(key)) uniques.add(w);
    }
    return uniques;
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(lockAspectRatio: true, toolbarTitle: 'Crop Image'),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );

    if (cropped == null) return;

    final bytes = await File(cropped.path).readAsBytes();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/custom_block_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    setState(() {
      _coverImageBytes = bytes;
      _coverImagePath = file.path;
    });
  }

  Future<void> _previewSchedule() async {
    if (numWeeks == null || daysPerWeek == null || workouts.isEmpty) return;

    // Simple STANDARD rotation: cycle through `workouts` across `numWeeks * daysPerWeek`.
    final totalDays = (numWeeks ?? 0) * (daysPerWeek ?? 0);
    final List<Map<String, dynamic>> dist = List.generate(totalDays, (i) {
      final week = (i ~/ (daysPerWeek!)) + 1;
      final dayIndex = i % daysPerWeek!;
      final workout = workouts[i % workouts.length];
      return {
        'week': week,
        'dayIndex': dayIndex,
        'workout': workout,
      };
    });

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Preview'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dist.length,
            itemBuilder: (_, i) {
              final item = dist[i];
              final w = item['workout'] as WorkoutDraft;
              return ListTile(
                dense: true,
                title: Text(
                  'Week ${item['week']} – Day ${item['dayIndex'] + 1}: '
                  '${w.name.isEmpty ? 'Workout ${w.id + 1}' : w.name}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkoutEditorFullscreen() async {
    int? activeInstanceId = widget.blockInstanceId;
    if (activeInstanceId == null) {
      activeInstanceId =
          await DBService().getBlockInstanceIdByCustomBlockId(widget.customBlockId);
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (ctx, __, ___) {
        int localIndex = _workoutIndex; // dialog-local index

        return StatefulBuilder(
          builder: (overlayCtx, setOverlayState) {
            void _setIndex(int i) {
              setOverlayState(() => localIndex = i); // update dialog UI
              setState(() => _workoutIndex = i); // keep wizard in sync
            }

            // Work directly on the primary workouts list so edits persist
            final List<WorkoutDraft> template = workouts;

            // Clamp index in case workout count changed
            if (template.isNotEmpty && localIndex >= template.length) {
              localIndex = template.length - 1;
            }

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: Text(
                  template.isEmpty
                      ? 'Edit Workouts'
                      : 'Edit Workouts (${localIndex + 1}/${template.length})',
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              body: SafeArea(
                child: template.isEmpty
                    ? const SizedBox.shrink()
                    : WorkoutBuilder(
                        key: ValueKey<int>(template[localIndex].id),
                        workout: template[localIndex],
                        allWorkouts: template, // operate on original list
                        currentIndex: localIndex,
                        onSelectWorkout: _setIndex, // reactive chip switching
                        isLast: localIndex == template.length - 1,
                        onComplete: () async {
                          if (localIndex < template.length - 1) {
                            _setIndex(localIndex + 1);
                            return;
                          }

                          if (activeInstanceId != null) {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Build Block?',
                              message:
                                  'This will rebuild instances. Removed weeks/lifts and their logged data will be deleted permanently.',
                            );
                            if (!ok) return;
                          }

                          final nav =
                              Navigator.of(context, rootNavigator: true);
                          final int? id = await _finish();
                          if (!mounted) return;

                          Navigator.of(ctx).pop(); // close full-screen editor

                          if (id != null) {
                            nav.pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BlockDashboard(blockInstanceId: id),
                              ),
                              result: true,
                            );
                          } else {
                            nav.pop(false);
                          }
                        },
                        showDumbbellOption: true,
                        customBlockId: widget.customBlockId,
                        activeBlockInstanceId: activeInstanceId,
                        onPreviewSchedule: _previewSchedule,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<int?> _finish() async {
    // Validate inputs
    if (blockName.trim().isEmpty || daysPerWeek == null || numWeeks == null)
      return null;
    if (workouts.isEmpty) return null;

    // 1) Expand the template across the full run
    final int totalDays = numWeeks! * daysPerWeek!;
    final baseId = DateTime.now().millisecondsSinceEpoch;

    final List<WorkoutDraft> allWorkouts = List.generate(totalDays, (i) {
      final template = workouts[i % workouts.length];
      return WorkoutDraft(
        id: baseId + i,
        dayIndex: i,
        name: template.name,
        lifts: [
          for (var j = 0; j < template.lifts.length; j++)
            LiftDraft(
              name: template.lifts[j].name,
              sets: template.lifts[j].sets,
              repsPerSet: template.lifts[j].repsPerSet,
              multiplier: template.lifts[j].multiplier,
              isBodyweight: template.lifts[j].isBodyweight,
              isDumbbellLift: template.lifts[j].isDumbbellLift,
              position: j,
            ),
        ],
        isPersisted: false,
      );
    });

    // 2) Build the CustomBlock
    final int id = widget.initialBlock?.id ?? widget.customBlockId;

    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: numWeeks!,
      daysPerWeek: daysPerWeek!,
      coverImagePath: _coverImagePath ?? 'assets/logo25.jpg',
      workouts: allWorkouts,
      isDraft: false,
      scheduleType: _scheduleType,
    );
    // 3) Resolve target instance and apply edits if possible
    final int? editedActiveInstanceId = await _resolveActiveInstanceId(block);
    if (editedActiveInstanceId != null) {
      await DBService().applyCustomBlockEdits(block, editedActiveInstanceId);
    } else {
      // Ensure block is stored for future runs
      await DBService().upsertCustomBlock(block);
    }

    // 4) Sync to Firestore (optional)
    await _uploadBlockToFirestore(block);

    // 5) Decide what to return
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // If we updated an active run, navigate to it
    if (editedActiveInstanceId != null) return editedActiveInstanceId;

    // Otherwise, ALWAYS build a fresh run and activate it
    final newInstanceId =
        await DBService().insertNewBlockInstance(block.name, user.uid);
    await DBService()
        .activateBlockInstanceIfNeeded(newInstanceId, user.uid, block.name);
    return newInstanceId;
  }

  /// Applies custom block edits to the user's active block instance (if any).
  /// Returns the blockInstanceId if edits were applied; otherwise null.
  /// Applies edits to an existing instance in priority order:
  /// 1) The instance we navigated from (widget.blockInstanceId), if present
  /// 2) The user's active instance with this name
  /// 3) The latest instance with this name
  /// Returns the instance id if applied; otherwise null.
  Future<int?> _resolveActiveInstanceId(CustomBlock block) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    int? targetInstanceId = widget.blockInstanceId;

    // Prefer direct lookup by custom block ID if no instance was supplied
    targetInstanceId ??=
        await DBService().getBlockInstanceIdByCustomBlockId(block.id);

    // Fallback to name-based lookups to handle legacy runs
    targetInstanceId ??=
        await DBService().findActiveInstanceIdByName(block.name, user.uid);

    targetInstanceId ??=
        await DBService().findLatestInstanceIdByName(block.name, user.uid);

    return targetInstanceId;
  }

  Future<void> _uploadBlockToFirestore(CustomBlock block) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? imageUrl;
    if (block.coverImagePath != null &&
        !block.coverImagePath!.startsWith('assets/')) {
      final file = File(block.coverImagePath!);
      if (await file.exists()) {
        final fileName =
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref =
            FirebaseStorage.instance.ref().child('block_covers/$fileName');
        final task = await ref.putFile(file);
        imageUrl = await task.ref.getDownloadURL();
      }
    }
    imageUrl ??= block.coverImagePath;

    final blockData = {
      'name': block.name,
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'scheduleType': block.scheduleType,
      'isDraft': block.isDraft,
      'coverImageUrl': imageUrl,
      'ownerId': user.uid,
      'source': 'mobile_custom_builder',
      'workouts': block.workouts
          .map((w) => {
                'id': w.id,
                'dayIndex': w.dayIndex,
                'name': w.name,
                'lifts': w.lifts
                    .map((l) => {
                          'name': l.name,
                          'sets': l.sets,
                          'repsPerSet': l.repsPerSet,
                          'multiplier': l.multiplier,
                          'isBodyweight': l.isBodyweight,
                          'isDumbbellLift': l.isDumbbellLift,
                        })
                    .toList(),
              })
          .toList(),
    };
    // Save to user's personal collection (for backwards compatibility)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set(blockData);

    // Save to global collection for sharing
    await FirebaseFirestore.instance
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set(blockData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Block'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (blockName.trim().isNotEmpty) {
              setState(() => _currentStep = 1);
            }
          } else if (_currentStep == 1) {
            setState(() => _currentStep = 2);
          } else if (_currentStep == 2) {
            if (_uniqueCount != null) {
              _initializeWorkouts();
              setState(() => _currentStep = 3);
            }
          } else if (_currentStep == 3) {
            if (daysPerWeek != null) {
              setState(() => _currentStep = 4);
            }
          } else if (_currentStep == 4) {
            if (numWeeks != null) {
              setState(() => _currentStep = 5);

              // open the editor full-screen once
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_openedEditorOnce) {
                  _openedEditorOnce = true;
                  _openWorkoutEditorFullscreen();
                }
              });
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          if (_currentStep < 5) {
            return Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: const Text('Next'),
                ),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
        steps: [
          Step(
            title: const Text('Block name'),
            content: TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => blockName = v,
              maxLength: 14,
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Cover image'),
            content: Column(
              children: [
                if (_coverImageBytes != null)
                  Image.memory(_coverImageBytes!,
                      height: 120, fit: BoxFit.cover)
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.5,
                        child: Image.asset('assets/logo25.jpg',
                            height: 120, fit: BoxFit.cover),
                      ),
                      Text(
                        blockName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ElevatedButton(
                  onPressed: _pickCoverImage,
                  child: Text(_coverImageBytes == null
                      ? 'Select Image'
                      : 'Change Image'),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('# Unique Workouts'),
            content: DropdownButton<int>(
              value: (_uniqueCount != null && _uniqueCount! >= 1 && _uniqueCount! <= 6)
                  ? _uniqueCount
                  : null, // <-- guard invalid (e.g., 0) to null
              hint: const Text('Select Count'),
              items: List.generate(6, (i) => i + 1)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                final newCount = v;
                final canApply = widget.blockInstanceId != null &&
                    newCount != null && daysPerWeek != null && numWeeks != null;
                if (canApply) {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Apply Shape Changes?',
                    message:
                        'This will rebuild instances. Removed weeks/lifts and their logged data will be deleted permanently.',
                  );
                  if (!ok) return;
                  await DBService().updateCustomBlockShape(
                    customBlockId: widget.customBlockId,
                    blockInstanceId: widget.blockInstanceId!,
                    uniqueWorkoutCount: newCount,
                    workoutsPerWeek: daysPerWeek!,
                    totalWeeks: numWeeks!,
                  );
                }
                setState(() => _uniqueCount = newCount);
              },
            ),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: const Text('Days per week?'),
            content: DropdownButton<int>(
              value: (daysPerWeek != null && daysPerWeek! >= 2 && daysPerWeek! <= 6)
                  ? daysPerWeek
                  : null, // <-- guard
              hint: const Text('Select Days'),
              items: List.generate(5, (i) => i + 2)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                final newDays = v;
                final canApply = widget.blockInstanceId != null &&
                    _uniqueCount != null && newDays != null && numWeeks != null;
                if (canApply) {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Apply Shape Changes?',
                    message:
                        'This will rebuild instances. Removed weeks/lifts and their logged data will be deleted permanently.',
                  );
                  if (!ok) return;
                  await DBService().updateCustomBlockShape(
                    customBlockId: widget.customBlockId,
                    blockInstanceId: widget.blockInstanceId!,
                    uniqueWorkoutCount: _uniqueCount!,
                    workoutsPerWeek: newDays,
                    totalWeeks: numWeeks!,
                  );
                }
                setState(() => daysPerWeek = newDays);
              },
            ),
            isActive: _currentStep >= 3,
          ),
          Step(
            title: const Text('How many weeks?'),
            content: DropdownButton<int>(
              value: (numWeeks != null && numWeeks! >= 3 && numWeeks! <= 6)
                  ? numWeeks
                  : null, // <-- guard
              hint: const Text('Select Weeks'),
              items: List.generate(4, (i) => i + 3)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                final newWeeks = v;
                final canApply = widget.blockInstanceId != null &&
                    _uniqueCount != null && daysPerWeek != null && newWeeks != null;
                if (canApply) {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Apply Shape Changes?',
                    message:
                        'This will rebuild instances. Removed weeks/lifts and their logged data will be deleted permanently.',
                  );
                  if (!ok) return;
                  await DBService().updateCustomBlockShape(
                    customBlockId: widget.customBlockId,
                    blockInstanceId: widget.blockInstanceId!,
                    uniqueWorkoutCount: _uniqueCount!,
                    workoutsPerWeek: daysPerWeek!,
                    totalWeeks: newWeeks,
                  );
                }
                setState(() => numWeeks = newWeeks);
              },
            ),
            isActive: _currentStep >= 4,
          ),
          Step(
            title: Text('Workout ${_workoutIndex + 1}'),
            content: const Text(
              'Opening full-screen workout editor… (Close it to return here.)',
              style: TextStyle(fontSize: 12),
            ),
            isActive: _currentStep >= 5,
          ),
        ],
      ),
    );
  }
}
