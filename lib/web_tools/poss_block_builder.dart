import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  void _onNameChanged() => setState(() {});
  int? _uniqueCount;
  int? _daysPerWeek;
  int? _numWeeks;
  // Schedule type defaults to standard. The deprecated schedule selection step
  // was removed so the value is fixed unless editing an existing block.
  String _scheduleType = 'standard';
  late List<CustomWorkout> _workouts;
  int _currentStep = 0;
  int _workoutIndex = 0;
  Uint8List? _coverImageBytes;
  String? _coverImageUrl;


  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    if (widget.initialBlock != null) {
      final block = widget.initialBlock!;
      _nameCtrl.text = block.name;  // Only use the controller now
      _numWeeks = block.numWeeks;
      _daysPerWeek = block.daysPerWeek;
      _scheduleType = block.scheduleType;
      final firstWeekWorkouts =
      block.workouts.where((w) => w.dayIndex < block.daysPerWeek).toList();
      _workouts = firstWeekWorkouts
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
      _uniqueCount = _workouts.length;
      _coverImageUrl = block.coverImagePath;
      // Editing an existing block jumps directly to the workout builder step.
      _currentStep = 5;
    } else {
      _workouts = [];
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

  void _initializeWorkouts() {
    final count = _uniqueCount ?? 0;
    _workouts = List.generate(
      count,
      (i) => CustomWorkout(
        id: i,
        name: 'Workout ${i + 1}',
        dayIndex: i,
        lifts: [],
      ),
    );
  }

  Future<void> _saveDraft() async {
    final blockName = _nameCtrl.text.trim();
    if (blockName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a block name')),
      );
      return;
    }
    if (_workouts.isEmpty && (_daysPerWeek ?? 0) > 0) {
      _initializeWorkouts();
    }
    final int id =
        widget.initialBlock?.id ?? DateTime.now().millisecondsSinceEpoch;
    final block = CustomBlock(
      id: id,
      name: blockName,
      numWeeks: _numWeeks ?? 1,
      daysPerWeek: _daysPerWeek ?? 1,
      scheduleType: _scheduleType,
      coverImagePath: _coverImageUrl,
      workouts: _workouts,
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
    if (_numWeeks == null ||
        _daysPerWeek == null ||
        _workouts.isEmpty) {
      return;
    }
    final dist = WebCustomBlockService().previewDistribution(
      _workouts,
      _numWeeks!,
      _daysPerWeek!,
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
            itemBuilder: (_, i) {
              final item = dist[i];
              return ListTile(
                title: Text(
                  'Week ${item['week']} – Day ${item['dayIndex'] + 1}: '
                  '${(item['workout'] as WorkoutDraft).name}',
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

  bool _isCurrentStepValid() {
    switch (_currentStep) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return true;
      case 2:
        return _uniqueCount != null;
      case 3:
        return _daysPerWeek != null;
      case 4:
        return _numWeeks != null;
      case 5:
        return true;
      default:
        return true;
    }
  }

  Future<void> _finish() async {
    final blockName = _nameCtrl.text.trim();
    if (_numWeeks == null ||
        _daysPerWeek == null ||
        blockName.isEmpty ||
        _workouts.isEmpty) {
      return;
    }

    // Workouts are stored only once. Day indexes correspond to the
    // template order rather than the final schedule.
    final List<WorkoutDraft> allWorkouts = [
      for (final w in _workouts)
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
      numWeeks: _numWeeks!,
      daysPerWeek: _daysPerWeek!,
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
          title: const Text('Training Block Builder'),
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
                    if (_nameCtrl.text.trim().isNotEmpty) {
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
                    if (_daysPerWeek != null) {
                      setState(() => _currentStep = 4);
                    }
                  } else if (_currentStep == 4) {
                    if (_numWeeks != null) {
                      setState(() => _currentStep = 5);
                    }
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                controlsBuilder: (context, details) {
                  final valid = _isCurrentStepValid();
                  const lastIndex = 5;
                  if (_currentStep < lastIndex) {
                    return Row(
                      children: [
                        ElevatedButton(
                          onPressed: valid ? details.onStepContinue : null,
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
              title: const Text('# Unique Workouts'),
              content: DropdownButton<int>(
                value: _uniqueCount,
                hint: const Text('Select Count'),
                items: List.generate(5, (i) => i + 2)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => _uniqueCount = v),
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Days per Week'),
              content: DropdownButton<int>(
                value: _daysPerWeek,
                hint: const Text('Select Days'),
                items: List.generate(5, (i) => i + 2)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => _daysPerWeek = v),
              ),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Block length (weeks)'),
              content: DropdownButton<int>(
                value: _numWeeks,
                hint: const Text('Select Weeks'),
                items: List.generate(4, (i) => i + 3)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => _numWeeks = v),
              ),
              isActive: _currentStep >= 4,
            ),
            Step(
              title: Text('Workout ${_workoutIndex + 1}'),
              content: Column(
                children: [
                  if (_workouts.isNotEmpty)
                    SizedBox(
                      height: 400,
                      child: WorkoutBuilder(
                        workout: _workouts[_workoutIndex],
                        allWorkouts: _workouts,
                        currentIndex: _workoutIndex,
                        onSelectWorkout: (i) =>
                            setState(() => _workoutIndex = i),
                        isLast: _workoutIndex == _workouts.length - 1,
                        showDumbbellOption: true,
                        onComplete: () async {
                          if (_workoutIndex < _workouts.length - 1) {
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
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }
}
