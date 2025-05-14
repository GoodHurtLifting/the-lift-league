import 'package:flutter/material.dart';

class CalculatorModal extends StatefulWidget {
  const CalculatorModal({super.key});

  @override
  State<CalculatorModal> createState() => _CalculatorModalState();
}

class _CalculatorModalState extends State<CalculatorModal> {
  bool showOneRepMax = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleButtons(
            isSelected: [showOneRepMax, !showOneRepMax],
            onPressed: (index) {
              setState(() => showOneRepMax = index == 0);
            },
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('1RM')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Plates')),
            ],
          ),
          const SizedBox(height: 20),
          showOneRepMax ? const OneRepMaxCalculator() : const PlateCalculator(),
        ],
      ),
    );
  }
}

//ONE REP MAX CALCULATOR

class OneRepMaxCalculator extends StatefulWidget {
  const OneRepMaxCalculator({super.key});

  @override
  State<OneRepMaxCalculator> createState() => _OneRepMaxCalculatorState();
}

class _OneRepMaxCalculatorState extends State<OneRepMaxCalculator> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  double? result;

  void _calculate1RM() {
    final double? weight = double.tryParse(_weightController.text);
    final int? reps = int.tryParse(_repsController.text);

    if (weight != null && reps != null && reps > 0) {
      // Epley formula
      setState(() => result = weight * (1 + reps / 30));
    }
  }
  double? percentageResult;
  double selectedPercentage = 0.9;

  void _calculatePercentage(double oneRepMax) {
    setState(() => percentageResult = oneRepMax * selectedPercentage);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight used (lbs)'),
        ),
        TextField(
          controller: _repsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Reps performed'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _calculate1RM, child: const Text('Calculate')),
        const SizedBox(height: 10),
        if (result != null) ...[
          Text('Estimated 1RM: ${result!.toStringAsFixed(1)} lbs',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Select % of 1RM:'),
              const SizedBox(width: 10),
              DropdownButton<double>(
                value: selectedPercentage,
                items: [0.9, 0.8, 0.7, 0.6, 0.5]
                    .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('${(p * 100).toStringAsFixed(0)}%'),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedPercentage = value;
                      _calculatePercentage(result!);
                    });
                  }
                },
              ),
            ],
          ),
          if (percentageResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${(selectedPercentage * 100).toStringAsFixed(0)}% of 1RM: ${percentageResult!.toStringAsFixed(1)} lbs'),
            ),
        ]
      ],
    );
  }
}

//PLATE CALCULATOR

class PlateCalculator extends StatefulWidget {
  const PlateCalculator({super.key});

  @override
  State<PlateCalculator> createState() => _PlateCalculatorState();
}

class _PlateCalculatorState extends State<PlateCalculator> {
  final TextEditingController _targetWeightController = TextEditingController();
  List<String> plates = [];

  void _calculatePlates() {
    final double? targetWeight = double.tryParse(_targetWeightController.text);
    if (targetWeight == null || targetWeight < 45) return;

    const barWeight = 45.0;
    const plateSizes = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];
    double weightPerSide = (targetWeight - barWeight) / 2;

    List<String> result = [];
    for (final plate in plateSizes) {
      int count = (weightPerSide ~/ plate).toInt();
      if (count > 0) {
        result.add('$count x ${plate}lb');
        weightPerSide -= count * plate;
      }
    }

    setState(() => plates = result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _targetWeightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target weight (lbs)'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _calculatePlates, child: const Text('Calculate')),
        const SizedBox(height: 10),
        if (plates.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Per side:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...plates.map((p) => Text(p)),
            ],
          ),
      ],
    );
  }
}
