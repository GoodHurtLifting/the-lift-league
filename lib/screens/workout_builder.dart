import 'package:flutter/material.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/data/lift_data.dart';
import 'package:lift_league/services/score_multiplier_service.dart';

class WorkoutBuilder extends StatefulWidget {
  final WorkoutDraft workout;
  final VoidCallback onComplete;
  const WorkoutBuilder({super.key, required this.workout, required this.onComplete});

  @override
  State<WorkoutBuilder> createState() => _WorkoutBuilderState();
}

class _WorkoutBuilderState extends State<WorkoutBuilder> {
  void _showAddLiftSheet() {
    final nameController = TextEditingController();
    int sets = 3;
    int reps = 10;
    bool isBodyweight = false;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final liftNames = liftDataList.map((e) => e['liftName'] as String).toList();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue text) {
                  if (text.text.isEmpty) return const Iterable<String>.empty();
                  return liftNames.where((n) => n.toLowerCase().contains(text.text.toLowerCase()));
                },
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  nameController.text = controller.text;
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(labelText: 'Lift name'),
                  );
                },
                onSelected: (v) => nameController.text = v,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Sets'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => sets = int.tryParse(v) ?? sets,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Reps'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => reps = int.tryParse(v) ?? reps,
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                value: isBodyweight,
                onChanged: (v) => setState(() => isBodyweight = v ?? false),
                title: const Text('Body-weight move'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final multiplier = ScoreMultiplierService().getMultiplier(
                    sets: sets,
                    repsPerSet: reps,
                    isBodyweight: isBodyweight,
                  );
                  setState(() {
                    widget.workout.lifts.add(LiftDraft(
                      name: name,
                      sets: sets,
                      repsPerSet: reps,
                      multiplier: multiplier,
                      isBodyweight: isBodyweight,
                    ));
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.workout.lifts.length,
            itemBuilder: (context, index) {
              final lift = widget.workout.lifts[index];
              return ListTile(
                title: Text(lift.name),
                subtitle: Text('${lift.sets} x ${lift.repsPerSet}'),
                trailing: Text(lift.multiplier.toStringAsFixed(3)),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: widget.onComplete,
          child: const Text('Next Workout'),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: _showAddLiftSheet,
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}