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
import 'package:lift_league/screens/workout_builder.dart';

class CustomBlockWizard extends StatefulWidget {
  final CustomBlock? initialBlock;
  const CustomBlockWizard({super.key, this.initialBlock});

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

  @override
  void initState() {
    super.initState();
    if (widget.initialBlock != null) {
      final block = widget.initialBlock!;
      blockName = block.name;
      numWeeks = block.numWeeks;
      daysPerWeek = block.daysPerWeek;
      _scheduleType = block.scheduleType;
      // Only include the first instance of each workout when editing.
      // This allows the user to edit one week and have the changes
      // applied across all repeated weeks when the block is saved.
      final firstWeekWorkouts =
          block.workouts.where((w) => w.dayIndex < block.daysPerWeek).toList();

      workouts = firstWeekWorkouts
          .map((w) => WorkoutDraft(
                id: w.id,
                dayIndex: w.dayIndex,
                name: w.name,
                lifts: w.lifts
                    .map(
                      (l) => LiftDraft(
                        name: l.name,
                        sets: l.sets,
                        repsPerSet: l.repsPerSet,
                        multiplier: l.multiplier,
                        isBodyweight: l.isBodyweight,
                        isDumbbellLift: l.isDumbbellLift,
                      ),
                    )
                    .toList(),
              ))
          .toList();
      _coverImagePath = block.coverImagePath;
      if (_coverImagePath != null && File(_coverImagePath!).existsSync()) {
        _coverImageBytes = File(_coverImagePath!).readAsBytesSync();
      }
      _nameCtrl.text = block.name;
      _currentStep = 5;
    } else {
      workouts = [];
    }
  }

  void _initializeWorkouts() {
    final count = _uniqueCount ?? 0;
    workouts = List.generate(
      count,
      (i) =>
          WorkoutDraft(id: i, dayIndex: i, name: 'Workout ${i + 1}', lifts: []),
    );
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

    setState(() {
      _coverImageBytes = bytes;
      _coverImagePath = file.path;
    });
  }

  Future<void> _saveDraft() async {
    if (blockName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a block name')),
      );
      return;
    }
    if (workouts.isEmpty && (_uniqueCount ?? 0) > 0) {
      _initializeWorkouts();
    }
    final int id =
        widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: numWeeks ?? 1,
      daysPerWeek: daysPerWeek ?? 1,
      coverImagePath: _coverImagePath ?? 'assets/logo25.jpg',
      workouts: workouts,
      isDraft: true,
      scheduleType: _scheduleType,
    );
    if (widget.initialBlock != null) {
      await DBService().updateCustomBlock(block);
    } else {
      await DBService().insertCustomBlock(block);
    }
    if (mounted) Navigator.pop(context);
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
                    'Week ${item['week']} – Day ${item['dayIndex'] + 1}: ${w.name.isEmpty ? 'Workout ${w.id + 1}' : w.name}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    final List<WorkoutDraft> allWorkouts = [
      for (final w in workouts)
        WorkoutDraft(
          id: w.id,
          dayIndex: w.dayIndex,
          name: w.name,
          lifts: [
            for (final l in w.lifts)
              LiftDraft(
                name: l.name,
                sets: l.sets,
                repsPerSet: l.repsPerSet,
                multiplier: l.multiplier,
                isBodyweight: l.isBodyweight,
                isDumbbellLift: l.isDumbbellLift,
              ),
          ],
        )
    ];

    final int id =
        widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
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
    if (widget.initialBlock != null) {
      await DBService().updateCustomBlock(block);
    } else {
      await DBService().insertCustomBlock(block);
    }
    await _uploadBlockToFirestore(block);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _uploadBlockToFirestore(CustomBlock block) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (block.isDraft) return;

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
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDraft,
            ),
        ],
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
              value: _uniqueCount,
              hint: const Text('Select Count'),
              items: List.generate(5, (i) => i + 2)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => _uniqueCount = v),
            ),
            isActive: _currentStep >= 4,
          ),
          Step(
            title: const Text('Days per week?'),
            content: DropdownButton<int>(
              value: daysPerWeek,
              hint: const Text('Select Days'),
              items: List.generate(5, (i) => i + 2)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => daysPerWeek = v),
            ),
            isActive: _currentStep >= 3,
          ),
          Step(
            title: const Text('How many weeks?'),
            content: DropdownButton<int>(
              value: numWeeks,
              hint: const Text('Select Weeks'),
              items: List.generate(4, (i) => i + 3)
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => numWeeks = v),
            ),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: Text('Workout ${_workoutIndex + 1}'),
            content: workouts.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 400,
                        child: WorkoutBuilder(
                          workout: workouts[_workoutIndex],
                          allWorkouts: workouts,
                          currentIndex: _workoutIndex,
                          onSelectWorkout: (i) =>
                              setState(() => _workoutIndex = i),
                          isLast: _workoutIndex == workouts.length - 1,
                          onComplete: () async {
                            if (_workoutIndex < workouts.length - 1) {
                              setState(() => _workoutIndex++);
                            } else {
                              await _finish();
                            }
                          },
                          showDumbbellOption: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _previewSchedule,
                        child: const Text('Preview Schedule'),
                      ),
                    ],
                  ),
            isActive: _currentStep >= 4,
          ),
        ],
      ),
    );
  }
}
