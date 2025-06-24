import 'package:flutter/material.dart';
import '../data/workout_metadata.dart';

class Workout411Screen extends StatelessWidget {
  final String blockName;

  const Workout411Screen({super.key, required this.blockName});

  WorkoutMetadata? _findMetadata() {
    try {
      return workoutMetadataList.firstWhere(
        (m) => m.name.toLowerCase() == blockName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _findMetadata();

    if (meta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('The 411')),
        body: const Center(child: Text('No info available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${meta.name} - The 411'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta.mainImage.isNotEmpty)
              Image.asset(meta.mainImage, fit: BoxFit.cover),
            const SizedBox(height: 16),
            Text(
              meta.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text('Category: ${meta.category}'),
            Text('Difficulty: ${meta.difficulty}'),
            Text('WO Duration: ${meta.woDuration}'),
            Text('Total Weeks: ${meta.totalWeeks}'),
            Text('Recommended For: ${meta.recommendedExperience}'),
            const SizedBox(height: 16),
            if (meta.equipmentNeeded.isNotEmpty) ...[
              const Text('Equipment Needed:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...meta.equipmentNeeded.map((e) => Text('- $e')),
            ],
            const SizedBox(height: 16),
            if (meta.scheduleImage.isNotEmpty)
              Image.asset(meta.scheduleImage, fit: BoxFit.cover),
            const SizedBox(height: 16),
            if (meta.liftList.isNotEmpty) ...[
              const Text('Lifts Included:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...meta.liftList.map((e) => Text('• $e')),
            ],
          ],
        ),
      ),
    );
  }
}

