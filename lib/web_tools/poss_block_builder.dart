import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'poss_drawer.dart';

import '../models/custom_block_models.dart';
import '../screens/workout_builder.dart';

const Color _lightGrey = Color(0xFFD0D0D0);

class POSSBlockBuilder extends StatefulWidget {
  final VoidCallback? onSaved;
  const POSSBlockBuilder({super.key, this.onSaved});

  @override
  State<POSSBlockBuilder> createState() => _POSSBlockBuilderState();
}

class _POSSBlockBuilderState extends State<POSSBlockBuilder> {
  final TextEditingController _nameCtrl = TextEditingController();
  String blockName = '';
  int? numWeeks;
  int? daysPerWeek;
  late List<WorkoutDraft> workouts;
  int _currentStep = 0;
  int _workoutIndex = 0;
  Uint8List? _coverImageBytes;
  String? _emailCapture;

  @override
  void initState() {
    super.initState();
    workouts = [];
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _coverImageBytes = bytes;
    });
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

  Future<void> _saveBlockToFirestore(CustomBlock block) async {
    String? imageUrl;
    final user = FirebaseAuth.instance.currentUser;

    if (_coverImageBytes != null) {
      final fileName =
          '${user?.uid ?? 'anon'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('block_covers/$fileName');
      final task = await ref.putData(
        _coverImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await task.ref.getDownloadURL();
    }

    final blockData = {
      'name': block.name,
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'isDraft': block.isDraft,
      'coverImageUrl': imageUrl,
      'ownerId': user?.uid ?? '',
      'source': 'web_custom_builder',
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

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('custom_blocks')
          .doc(block.id.toString())
          .set(blockData);
    } else if (_emailCapture != null && _emailCapture!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('web_custom_blocks')
          .doc(_emailCapture)
          .collection('blocks')
          .doc(block.id.toString())
          .set(blockData);
    }

    await FirebaseFirestore.instance
        .collection('custom_blocks')
        .doc(block.id.toString())
        .set(blockData);
  }

  Future<void> _promptForAuth() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To keep this block we need a way to attach it to you.\n'
                'Sign in with Google or provide an email to link it to your account.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final googleUser = await GoogleSignIn().signIn();
                    if (googleUser == null) return;
                    final googleAuth = await googleUser.authentication;
                    final cred = GoogleAuthProvider.credential(
                      accessToken: googleAuth.accessToken,
                      idToken: googleAuth.idToken,
                    );
                    await FirebaseAuth.instance.signInWithCredential(cred);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {}
                },
                child: const Text('Sign in with Google'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _emailCapture = emailCtrl.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finish() async {
    if (numWeeks == null ||
        daysPerWeek == null ||
        blockName.trim().isEmpty ||
        workouts.isEmpty) {
      return;
    }

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
                  isDumbbellLift: l.isDumbbellLift,
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

    await _promptForAuth();

    final block = CustomBlock(
      id: DateTime.now().millisecondsSinceEpoch,
      name: blockName,
      numWeeks: numWeeks!,
      daysPerWeek: daysPerWeek!,
      coverImagePath: null,
      workouts: allWorkouts,
      isDraft: false,
    );

    await _saveBlockToFirestore(block);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Block saved!')));
    }
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: _lightGrey),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          foregroundColor: _lightGrey,
          title: const Text('Build Training Block'),
        ),
        drawer: const POSSDrawer(),
        body: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Stepper(
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
                    Image.memory(
                      _coverImageBytes!,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  else
                    const Placeholder(fallbackHeight: 120),
                  ElevatedButton(
                    onPressed: _pickCoverImage,
                    child: Text(
                      _coverImageBytes == null
                          ? 'Select Image'
                          : 'Change Image',
                    ),
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
                        onSelectWorkout: (i) =>
                            setState(() => _workoutIndex = i),
                        isLast: _workoutIndex == workouts.length - 1,
                        showDumbbellOption: true,
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
