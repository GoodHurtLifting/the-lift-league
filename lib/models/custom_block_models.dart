class CustomBlock {
  final int id;
  final String name;
  final int numWeeks;
  final int daysPerWeek;
  final bool isDraft;
  final String scheduleType;
  final String? coverImagePath;
  final List<WorkoutDraft> workouts;

  CustomBlock({
    required this.id,
    required this.name,
    required this.numWeeks,
    required this.daysPerWeek,
    required this.workouts,
    this.scheduleType = 'standard',
    this.coverImagePath,
    this.isDraft = false,
  });

  factory CustomBlock.fromMap(Map<String, dynamic> data) {
    List<dynamic> workoutList = data['workouts'] ?? [];
    return CustomBlock(
      id: data['id'] ?? 0,
      name: data['name'] ?? '',
      numWeeks: data['numWeeks'] ?? 1,
      daysPerWeek: data['daysPerWeek'] ?? 1,
      coverImagePath: data['coverImageUrl'] ?? data['coverImagePath'],
      isDraft: data['isDraft'] ?? false,
      scheduleType: data['scheduleType'] ?? 'standard',
      workouts: workoutList.map<WorkoutDraft>((w) {
        List<dynamic> liftList = w['lifts'] ?? [];
        return WorkoutDraft(
          id: w['id'] ?? 0,
          dayIndex: w['dayIndex'] ?? 0,
          name: w['name'] ?? '',
          lifts: liftList.map<LiftDraft>((l) {
            return LiftDraft(
              name: l['name'] ?? '',
              sets: l['sets'] ?? 0,
              repsPerSet: l['repsPerSet'] ?? 0,
              multiplier: (l['multiplier'] as num?)?.toDouble() ?? 1.0,
              isBodyweight: l['isBodyweight'] ?? false,
              isDumbbellLift: l['isDumbbellLift'] ?? false,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class WorkoutDraft {
  int id;
  int dayIndex;
  String name;
  List<LiftDraft> lifts;
  WorkoutDraft({
    required this.id,
    required this.dayIndex,
    required this.name,
    required this.lifts,
  });
}

class LiftDraft {
  String name;
  int sets;
  int repsPerSet;
  double multiplier;
  bool isBodyweight;
  bool isDumbbellLift;
  LiftDraft({
    required this.name,
    required this.sets,
    required this.repsPerSet,
    required this.multiplier,
    required this.isBodyweight,
    this.isDumbbellLift = false,
  });
}