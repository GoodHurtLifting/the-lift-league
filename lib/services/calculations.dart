import 'package:flutter/material.dart';

// ✅ Sums up all lift workloads
double calculateWorkoutWorkload(List<double> workloads) =>
    workloads.fold(0.0, (sum, value) => sum + value);

// ✅ Calculates total weight used across sets (entered via text fields)
double getSetsWeightUsed(List<TextEditingController> weightControllers) =>
    weightControllers.fold(0.0, (sum, c) => sum + (double.tryParse(c.text) ?? 0.0));

// ✅ Calculates total weight used individual weight for each set pulled from database
double getLiftWeightFromDb(List<Map<String, dynamic>> entries) {
  return entries.fold(0.0, (sum, entry) {
    double weight = (entry['weight'] as num?)?.toDouble() ?? 0.0;
    return sum + weight;
  });
}

// ✅ Average of lift scores across all lifts
double calculateWorkoutScore(List<double> scores) =>
    scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

double calculatePreviousWorkoutScore(List<double> prevLiftScore) =>
    prevLiftScore.isEmpty ? 0.0 : prevLiftScore.reduce((a, b) => a + b) / prevLiftScore.length;


// =============================
// Functions for calculations based on active TextEditingControllers
// (Used for real-time UI feedback)
// =============================

// ✅ Calculates total reps from text fields (handles dumbbells properly)
int getLiftReps(List<TextEditingController> repsControllers, {required bool isDumbbellLift}) {
  int liftReps = repsControllers.fold(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));
  return isDumbbellLift ? liftReps * 2 : liftReps;
}

// ✅ Calculates individual lift workload from controllers
double getLiftWorkload(
    List<TextEditingController> repsControllers,
    List<TextEditingController> weightControllers,
    {required bool isDumbbellLift}
    ) {
  double workload = 0.0;
  for (int i = 0; i < repsControllers.length; i++) {
    int reps = int.tryParse(repsControllers[i].text) ?? 0;
    double weight = double.tryParse(weightControllers[i].text) ?? 0.0;
    workload += reps * weight;
  }
  return isDumbbellLift ? workload * 2 : workload;
}

// ✅ Calculates lift score from controllers (immediate UI calculation)
double getLiftScore(
    List<TextEditingController> repsControllers,
    List<TextEditingController> weightControllers,
    double scoreMultiplier,
    {required bool isDumbbellLift, required String scoreType}
    ) {
  if (scoreType == 'bodyweight') {
    double totalWeight = getSetsWeightUsed(weightControllers);
    int liftReps = getLiftReps(repsControllers, isDumbbellLift: isDumbbellLift);
    double score = liftReps + (0.5 * totalWeight);
    return double.parse(score.toStringAsFixed(1));
  }

  // Default multiplier-based formula
  double totalWeight = getSetsWeightUsed(weightControllers);
  int liftReps = getLiftReps(repsControllers, isDumbbellLift: isDumbbellLift);
  double score = totalWeight * liftReps * scoreMultiplier;
  return double.parse(score.toStringAsFixed(1));
}

// =============================
// Functions for calculations based on raw DB entry maps
// (Used to update the totals stored in the DB)
// =============================

// ✅ Calculates individual lift workload from raw DB entry maps
double getLiftWorkloadFromDb(List<Map<String, dynamic>> entries, {required bool isDumbbellLift}) {
  double liftWorkload = 0.0;
  for (final entry in entries) {
    final reps = (entry['reps'] as int?) ?? 0;
    final weight = (entry['weight'] as num?)?.toDouble() ?? 0.0;
    liftWorkload += reps * weight;
  }
  return isDumbbellLift ? liftWorkload * 2 : liftWorkload;
}

// ✅ Calculates total reps from DB entries
int getLiftRepsFromDb(List<Map<String, dynamic>> entries, {required bool isDumbbellLift}) {
  int liftReps = 0;
  for (final entry in entries) {
    final reps = (entry['reps'] as int?) ?? 0;
    liftReps += isDumbbellLift ? reps * 2 : reps;
  }
  return liftReps;
}

// ✅ Calculates lift score from raw DB entry maps.
double calculateLiftScoreFromEntries(
    List<Map<String, dynamic>> entries,
    double scoreMultiplier, {
      required bool isDumbbellLift,
      required String scoreType,
    }) {
  if (scoreType == 'bodyweight') {
    int liftReps = getLiftRepsFromDb(entries, isDumbbellLift: isDumbbellLift);
    // Use the DB version that mimics getSetsWeightUsed
    double totalWeight = getLiftWeightFromDb(entries);
    double score = liftReps + (0.5 * totalWeight);
    return double.parse(score.toStringAsFixed(1));
  }
  // Default multiplier-based formula remains unchanged:
  double totalWeight = getLiftWorkloadFromDb(entries, isDumbbellLift: isDumbbellLift);
  int liftReps = getLiftRepsFromDb(entries, isDumbbellLift: isDumbbellLift);
  double score = totalWeight * liftReps * scoreMultiplier;
  return double.parse(score.toStringAsFixed(1));
}

// ✅ Calculates recommended weight based on reference values
double getRecommendedWeight({
  required int liftId,
  required double referenceWeight,
  required double percentOfReference,
}) {
  return (referenceWeight * percentOfReference).roundToDouble();
}
