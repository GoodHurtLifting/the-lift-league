class Workout {
  final int blockInstanceId;
  final int workoutInstanceId;
  final String blockName;
  final String name; // Workout name (e.g., "Push - Day 1")
  final List<Liftinfo> lifts; // List of lifts in this workout
  final double workoutScore;
  final int workoutId;

  Workout({
    required this.blockInstanceId,
    required this.workoutInstanceId,
    required this.blockName,
    required this.name,
    required this.lifts,
    required this.workoutScore,
    required this.workoutId,
  });

// ✅ Factory method to create a Workout from DB results
  factory Workout.fromMap(Map<String, dynamic> map, List<Liftinfo> lifts) {
    final rawScore = map['workoutScore'];
    final parsedScore = rawScore != null
        ? (rawScore is double
        ? rawScore
        : (rawScore is int ? rawScore.toDouble() : 0.0))
        : 0.0;

    return Workout(
      blockInstanceId: map['blockInstanceId'],
      workoutInstanceId: map['workoutInstanceId'],
      blockName: map['blockName'],
      name: map['name'],
      lifts: lifts,
      workoutScore: parsedScore,
      workoutId: map['workoutId'],
    );
  }

  // ✅ Convert Workout object to DB-compatible map
  Map<String, dynamic> toMap() {
    return {
      'blockInstanceId': blockInstanceId,
      'workoutInstanceId': workoutInstanceId,
      'blockName': blockName,
      'name': name,
      'workoutScore' : workoutScore,
      'workoutId': workoutId,

    };
  }
}

// ✅ Represents real-time totals for a specific workout instance
class WorkoutInstanceTotals {
  final double workoutScore;
  final double workoutWorkload;
  final double previousWorkoutScore;

  WorkoutInstanceTotals({
    required this.workoutScore,
    required this.workoutWorkload,
    required this.previousWorkoutScore,
  });
}

class Liftinfo {
  final int liftId;
  final String liftName;
  final String repScheme;
  final int numSets;
  final double scoreMultiplier;
  final bool isDumbbellLift;
  final String scoreType;
  final String youtubeUrl;
  final String description;
  final int? workoutInstanceId;
  final int storedLiftTotalReps;
  final double storedLiftTotalWorkload;
  final double storedLiftScore;
  final int? referenceLiftId;
  final double? percentOfReference;


  Liftinfo({
    required this.liftId,
    required this.liftName,
    required this.repScheme,
    required this.numSets,
    required this.scoreMultiplier,
    required this.isDumbbellLift,
    required this.scoreType,
    required this.youtubeUrl,
    required this.description,
    this.workoutInstanceId,
    this.storedLiftTotalReps = 0,
    this.storedLiftTotalWorkload = 0.0,
    this.storedLiftScore = 0.0,
    this.referenceLiftId,
    this.percentOfReference,
  });

  // ✅ Placeholder constructor for initial workout data
  factory Liftinfo.placeholder(int liftId, int workoutInstanceId) {
    return Liftinfo(
      liftId: liftId,
      liftName: "Placeholder", // ✅ Will be fetched from DB later
      repScheme: "",
      numSets: 0,
      scoreMultiplier: 0.0,
      isDumbbellLift: false,
      scoreType: "",
      youtubeUrl: "",
      description: "",
      workoutInstanceId: workoutInstanceId,
    );
  }

  // ✅ Convert Liftinfo object to DB-compatible map
  Map<String, dynamic> toMap() {
    return {
      'liftId': liftId,
      'liftName': liftName,
      'repScheme': repScheme,
      'numSets': numSets,
      'scoreMultiplier': scoreMultiplier,
      'isDumbbellLift': isDumbbellLift ? 1 : 0,
      'scoreType': scoreType,
      'youtubeUrl': youtubeUrl,
      'description': description,
      if (workoutInstanceId != null) 'workoutInstanceId': workoutInstanceId,
      'storedLiftTotalReps': storedLiftTotalReps,
      'storedLiftTotalWorkload': storedLiftTotalWorkload,
      'storedLiftScore': storedLiftScore,
    };
  }

}
