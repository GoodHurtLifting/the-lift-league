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
      workouts = block.workouts
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
                      ),
                    )
                    .toList(),
              ))
          .toList();
      _coverImagePath = block.coverImagePath;
      if (_coverImagePath != null && File(_coverImagePath!).existsSync()) {
        _coverImageBytes = File(_coverImagePath!).readAsBytesSync();
      }
      _currentStep = 4;
    } else {
      workouts = [];
    }
  }

  void _createDrafts() {
    final count = daysPerWeek ?? 0;
    final List<WorkoutDraft> newList = List.generate(
      count,
      (i) => WorkoutDraft(id: i, dayIndex: i, name: '', lifts: []),
    );
    for (var i = 0; i < newList.length && i < workouts.length; i++) {
      newList[i] = workouts[i];
    }
    workouts = newList;
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
    if (workouts.isEmpty && (daysPerWeek ?? 0) > 0) {
      _createDrafts();
    }
    final int id = widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: numWeeks ?? 1,
      daysPerWeek: daysPerWeek ?? 1,
      coverImagePath: _coverImagePath ?? 'assets/logo25.jpg',
      workouts: workouts,
      isDraft: true,
    );
    if (widget.initialBlock != null) {
      await DBService().updateCustomBlock(block);
    } else {
      await DBService().insertCustomBlock(block);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finish() async {
    final List<WorkoutDraft> allWorkouts = [];
    int idCounter = 0;
    for (var week = 0; week < (numWeeks ?? 0); week++) {
      for (var day = 0; day < workouts.length; day++) {
        final base = workouts[day];
        final copiedLifts = base.lifts
            .map((l) => LiftDraft(
                  name: l.name,
                  sets: l.sets,
                  repsPerSet: l.repsPerSet,
                  multiplier: l.multiplier,
                  isBodyweight: l.isBodyweight,
                ))
            .toList();
        allWorkouts.add(WorkoutDraft(
          id: idCounter++,
          dayIndex: week * workouts.length + day,
          name: base.name,
          lifts: copiedLifts,
        ));
      }
    }

    final int id = widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: numWeeks!,
      daysPerWeek: daysPerWeek!,
      coverImagePath: _coverImagePath ?? 'assets/logo25.jpg',
      workouts: allWorkouts,
      isDraft: false,
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

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set({
      'name': block.name,
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'isDraft': block.isDraft,
      'coverImageUrl': imageUrl,
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
        })
            .toList(),
      })
          .toList(),
    });
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
            if (numWeeks != null) {
              setState(() => _currentStep = 3);
            }
          } else if (_currentStep == 3) {
            if (daysPerWeek != null) {
              _createDrafts();
              setState(() => _currentStep = 4);
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
          if (_currentStep < 4) {
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
                  Image.memory(_coverImageBytes!, height: 120, fit: BoxFit.cover)
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.5,
                        child: Image.asset('assets/logo25.jpg', height: 120, fit: BoxFit.cover),
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
                  ),                ElevatedButton(
                  onPressed: _pickCoverImage,
                  child: Text(_coverImageBytes == null ? 'Select Image' : 'Change Image'),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
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
            title: Text('Workout ${_workoutIndex + 1}'),
            content: workouts.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 400,
                    child: WorkoutBuilder(
                      workout: workouts[_workoutIndex],
                      allWorkouts: workouts,
                      currentIndex: _workoutIndex,
                      onSelectWorkout: (i) => setState(() => _workoutIndex = i),
                      isLast: _workoutIndex == workouts.length - 1,
                      onComplete: () async {
                        if (_workoutIndex < workouts.length - 1) {
                          setState(() => _workoutIndex++);
                        } else {
                          await _finish();
                        }
                      },
                    ),
                  ),
            isActive: _currentStep >= 4,
          ),
        ],
      ),
    );
  }
}