import 'package:flutter/material.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/screens/workout_builder.dart';

class CustomBlockWizard extends StatefulWidget {
  const CustomBlockWizard({super.key});

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

  @override
  void initState() {
    super.initState();
    workouts = [];
  }

  void _createDrafts() {
    final count = daysPerWeek ?? 0;
    workouts = List.generate(
      count,
      (i) => WorkoutDraft(id: i, dayIndex: i, name: '', lifts: []),
    );
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
    final block = CustomBlock(
      id: DateTime.now().millisecondsSinceEpoch,
      name: blockName,
      numWeeks: numWeeks ?? 1,
      daysPerWeek: daysPerWeek ?? 1,
      workouts: workouts,
      isDraft: true,
    );
    await DBService().insertCustomBlock(block);
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

    final block = CustomBlock(
      id: DateTime.now().millisecondsSinceEpoch,
      name: blockName,
      numWeeks: numWeeks!,
      daysPerWeek: daysPerWeek!,
      workouts: allWorkouts,
      isDraft: false,
    );


    await DBService().insertCustomBlock(block);
    if (mounted) Navigator.pop(context);
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
            if (numWeeks != null) {
              setState(() => _currentStep = 2);
            }
          } else if (_currentStep == 2) {
            if (daysPerWeek != null) {
              _createDrafts();
              setState(() => _currentStep = 3);
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
          if (_currentStep < 3) {
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
            ),
            isActive: _currentStep >= 0,
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
            isActive: _currentStep >= 1,
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
            isActive: _currentStep >= 2,
          ),
          Step(
            title: Text('Workout ${_workoutIndex + 1}'),
            content: workouts.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 400,
                    child: WorkoutBuilder(
                      workout: workouts[_workoutIndex],
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
            isActive: _currentStep >= 3,
          ),
        ],
      ),
    );
  }
}