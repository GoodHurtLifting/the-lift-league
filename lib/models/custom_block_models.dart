class CustomBlock {
  final int id;
  final String name;
  final int numWeeks;
  final int daysPerWeek;
  final List<WorkoutDraft> workouts;

  CustomBlock({
    required this.id,
    required this.name,
    required this.numWeeks,
    required this.daysPerWeek,
    required this.workouts,
  });
}

class WorkoutDraft {
  int id;
  int dayIndex;
  List<LiftDraft> lifts;
  WorkoutDraft({required this.id, required this.dayIndex, required this.lifts});
}

class LiftDraft {
  String name;
  int sets;
  int repsPerSet;
  double multiplier;
  bool isBodyweight;
  LiftDraft({
    required this.name,
    required this.sets,
    required this.repsPerSet,
    required this.multiplier,
    required this.isBodyweight,
  });
}