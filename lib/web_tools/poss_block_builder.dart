import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/google_auth_service.dart';
import 'poss_drawer.dart';
import 'web_sign_in_dialog.dart';
import 'auth_utils.dart';

import '../models/custom_block_models.dart';
import '../screens/workout_builder.dart';
import '../services/db_service.dart';
import '../screens/block_dashboard.dart';
import 'web_block_dashboard.dart';
import 'web_custom_block_service.dart';

const Color _lightGrey = Color(0xFFD0D0D0);

class POSSBlockBuilder extends StatefulWidget {
  final VoidCallback? onSaved;
  final CustomBlock? initialBlock;
  const POSSBlockBuilder({super.key, this.onSaved, this.initialBlock});

  @override
  State<POSSBlockBuilder> createState() => _POSSBlockBuilderState();
}

class _POSSBlockBuilderState extends State<POSSBlockBuilder> {
  final TextEditingController _nameCtrl = TextEditingController();
  String blockName = '';
  int? _selectedWeeks;
  int? _selectedDaysPerWeek;
  String _scheduleType = 'standard';
  late List<WorkoutDraft> workouts;
  int _currentStep = 0;
  int _workoutIndex = 0;
  Uint8List? _coverImageBytes;
  String? _coverImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialBlock != null) {
      final block = widget.initialBlock!;
      blockName = block.name;
      _nameCtrl.text = blockName;
      _selectedWeeks = block.numWeeks;
      _selectedDaysPerWeek = block.daysPerWeek;
      _scheduleType = block.scheduleType;
      final firstWeekWorkouts =
          block.workouts.where((w) => w.dayIndex < block.daysPerWeek).toList();
      workouts = firstWeekWorkouts
          .map(
            (w) => WorkoutDraft(
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
            ),
          )
          .toList();
      _coverImageUrl = block.coverImagePath;
      _currentStep = 5;
    } else {
      workouts = [];
    }
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _coverImageBytes = bytes;
      _coverImageUrl = null;
    });
  }

  void _createDrafts() {
    final count = _selectedDaysPerWeek ?? 0;
    final List<WorkoutDraft> newList = List.generate(
      count,
      (i) => WorkoutDraft(id: i, dayIndex: i, name: '', lifts: []),
    );
    for (var i = 0; i < newList.length && i < workouts.length; i++) {
      newList[i] = workouts[i];
    }
    workouts = newList;
  }

  Future<void> _saveDraft() async {
    if (blockName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a block name')),
      );
      return;
    }
    if (workouts.isEmpty && (_selectedDaysPerWeek ?? 0) > 0) {
      _createDrafts();
    }
    final int id =
        widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: _selectedWeeks ?? 1,
      daysPerWeek: _selectedDaysPerWeek ?? 1,
      scheduleType: _scheduleType,
      coverImagePath: _coverImageUrl,
      workouts: workouts,
      isDraft: true,
    );
    try {
      await WebCustomBlockService()
          .saveCustomBlock(block, coverImageBytes: _coverImageBytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft saved')));
        Navigator.pop(context);
      }
      widget.onSaved?.call();
    } on FirebaseException catch (e) {
      final reauthed = await promptReAuthIfNeeded(context, e);
      if (reauthed) {
        await WebCustomBlockService()
            .saveCustomBlock(block, coverImageBytes: _coverImageBytes);
      } else {
        return;
      }
    }
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
    } else if (_coverImageUrl != null) {
      imageUrl = _coverImageUrl;
    }

    final blockData = {
      'name': block.name,
      'numWeeks': block.numWeeks,
      'daysPerWeek': block.daysPerWeek,
      'scheduleType': block.scheduleType,
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

      // Also store under the global collection so blocks created on the web
      // are available and shareable in the mobile app just like those built
      // on mobile.
      await FirebaseFirestore.instance
          .collection('custom_blocks')
          .doc(block.id.toString())
          .set(blockData);
    } else {
      return;
    }
    // Blocks are saved for the signed-in user and globally for sharing.
  }

  Future<void> _previewSchedule() async {
    if (_selectedWeeks == null ||
        _selectedDaysPerWeek == null ||
        workouts.isEmpty) {
      return;
    }
    final dist = WebCustomBlockService().previewDistribution(
      workouts,
      _selectedWeeks!,
      _selectedDaysPerWeek!,
      _scheduleType,
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Preview'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dist.length,
            itemBuilder: (context, index) {
              final item = dist[index];
              final w = item['workout'] as WorkoutDraft;
              final week = item['week'] as int;
              final day = (item['dayIndex'] as int) + 1;
              return ListTile(
                dense: true,
                title: Text('Week $week, Day $day: ${w.name}'),
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

  Future<void> _finish() async {
    if (_selectedWeeks == null ||
        _selectedDaysPerWeek == null ||
        blockName.trim().isEmpty ||
        workouts.isEmpty) {
      return;
    }

    // Workouts are stored only once. Day indexes correspond to the
    // template order rather than the final schedule.
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

    if (FirebaseAuth.instance.currentUser == null) {
      final signedIn = await showWebSignInDialog(context);
      if (!signedIn) return;
    }

    final block = CustomBlock(
      id: widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch,
      name: blockName,
      numWeeks: _selectedWeeks!,
      daysPerWeek: _selectedDaysPerWeek!,
      scheduleType: _scheduleType,
      coverImagePath: _coverImageUrl,
      workouts: allWorkouts,
      isDraft: false,
    );

    if (kIsWeb) {
      try {
        await _saveBlockToFirestore(block);
        final runId = await WebCustomBlockService().startBlockRun(block);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Block saved!')));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  WebBlockDashboard(block: block, runId: runId),
            ),
          );
        }
      } on FirebaseException catch (e) {
        final reauthed = await promptReAuthIfNeeded(context, e);
        if (reauthed) {
          final runId = await WebCustomBlockService().startBlockRun(block);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Block saved!')));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WebBlockDashboard(block: block, runId: runId),
              ),
            );
          }
        } else {
          return;
        }
      }
      widget.onSaved?.call();
      return;
    }

    // Save locally and build block dashboard just like the mobile app
    final db = DBService();
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await db.insertCustomBlock(block);
    final int blockInstanceId =
        await db.createBlockFromCustomBlockId(block.id, userId);

    try {
      await _saveBlockToFirestore(block);
    } on FirebaseException catch (e) {
      final reauthed = await promptReAuthIfNeeded(context, e);
      if (reauthed) {
        await _saveBlockToFirestore(block);
      } else {
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Block saved!')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlockDashboard(blockInstanceId: blockInstanceId),
        ),
      );
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
          actions: [
            if (_currentStep > 0)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveDraft,
              ),
          ],
        ),
        drawer: const POSSDrawer(),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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
                if (_selectedWeeks != null) {
                  setState(() => _currentStep = 3);
                }
              } else if (_currentStep == 3) {
                if (_selectedDaysPerWeek != null) {
                  _createDrafts();
                  setState(() => _currentStep = 4);
                }
              } else if (_currentStep == 4) {
                setState(() => _currentStep = 5);
              }
            },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
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
                    Image.memory(
                      _coverImageBytes!,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  else if (_coverImageUrl != null)
                    Image.network(
                      _coverImageUrl!,
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
                value: _selectedWeeks,
                hint: const Text('Select Weeks'),
                items: List.generate(4, (i) => i + 3)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWeeks = v),
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Workouts per week?'),
              content: DropdownButton<int>(
                value: _selectedDaysPerWeek,
                hint: const Text('Select Days'),
                items: List.generate(5, (i) => i + 2)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDaysPerWeek = v),
              ),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Schedule type'),
              content: DropdownButton<String>(
                value: _scheduleType,
                items: [
                  const DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(
                    value: 'ab_alternate',
                    enabled: _selectedDaysPerWeek == 3 && workouts.length == 2,
                    child: const Text('A/B Alternate'),
                  ),
                ],
                onChanged: (v) => setState(() => _scheduleType = v ?? 'standard'),
              ),
              isActive: _currentStep >= 4,
            ),
            Step(
              title: Text('Workout ${_workoutIndex + 1}'),
              content: Column(
                children: [
                  if (workouts.isNotEmpty)
                    SizedBox(
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
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _previewSchedule,
                    child: const Text('Preview Schedule'),
                  ),
                ],
              ),
              isActive: _currentStep >= 5,
            ),
          ],
        ),
        ),
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
