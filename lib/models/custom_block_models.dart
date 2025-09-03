class CustomBlock {
  final int id;
  final String name;
  /// Duration of the block in weeks. When persisted to the database this is
  /// stored in the `totalWeeks` column of the `custom_blocks` table.
  final int numWeeks;

  /// Number of workouts per week. When persisted to the database this maps to
  /// the `workoutsPerWeek` column of the `custom_blocks` table.
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
      // Support both UI field names and DB column names for flexibility.
      numWeeks: data['numWeeks'] ?? data['totalWeeks'] ?? 1,
      daysPerWeek:
          data['daysPerWeek'] ?? data['workoutsPerWeek'] ?? 1,
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
              position: l['position'] ?? 0,
            );
          }).toList(),
          isPersisted: true,
        );
      }).toList(),
    );
  }
}

class CustomBlockForEdit extends CustomBlock {
  CustomBlockForEdit({
    required super.id,
    required super.name,
    required super.numWeeks,
    required super.daysPerWeek,
    required super.workouts,
    super.scheduleType,
    super.coverImagePath,
    super.isDraft,
  });
}

class WorkoutDraft {
  int id;
  int dayIndex;
  String name;
  List<LiftDraft> lifts;
  bool isPersisted;
  WorkoutDraft({
    required this.id,
    required this.dayIndex,
    required this.name,
    required this.lifts,
    this.isPersisted = true,
  });
}

class LiftDraft {
  int? id; // liftInstanceId when editing existing custom workouts
  String name;
  int sets;
  int repsPerSet;
  double multiplier;
  bool isBodyweight;
  bool isDumbbellLift;
  int position;
  LiftDraft({
    this.id,
    required this.name,
    required this.sets,
    required this.repsPerSet,
    required this.multiplier,
    required this.isBodyweight,
    this.isDumbbellLift = false,
    this.position = 0,
  });
}