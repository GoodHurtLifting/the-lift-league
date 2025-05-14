class WorkoutMetadata {
  final int id;  // Unique identifier for the workout block
  final String name; // Name of the workout block
  final String category; // Powerbuilding, Strength Training, Bodybuilding
  final String description; // Overview of the block
  final String difficulty; // Beginner, Intermediate, Advanced
  final int totalWeeks; // Duration of the program in weeks
  final String recommendedExperience; // Who it's best suited for
  final List<String> equipmentNeeded; // Equipment requirements
  final String scheduleImage; // Path to schedule image
  final String mainImage; // Path to main image for the block
  final List<String> liftList; // List of lifts included

  const WorkoutMetadata({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.difficulty,
    required this.totalWeeks,
    required this.recommendedExperience,
    required this.equipmentNeeded,
    required this.scheduleImage,
    required this.mainImage,
    required this.liftList,
  });
}

// ✅ Centralized Path Constants for Images
const String baseSchedulePath = "assets/schedules/";
const String baseImagePath = "assets/images/";

// ✅ List of training blocks with metadata
const List<WorkoutMetadata> workoutMetadataList = [
  WorkoutMetadata(
    id: 1,
    name: "Push Pull Legs",
    category: "Powerbuilding",
    description: "The Lift League Push Pull Legs is an excellent program for beginners. Combining compound lifts and muscle-isolating exercises, the Push Pull Legs hits each muscle group while providing extended recovery time before retraining. If you are new to weightlifting, grab the PPL and a league coaching session. We'll have you kicking ass in the gym in no time. For anyone new to weightlifting, start with weight amounts that allow you to comfortably perform each recommended rep scheme. Study the reference video linked to the name of each exercise. Follow the notes included with each exercise and gradually add weight every week while focusing on maintaining good form. If you want more practice, repeat the program. There is no pressure to advance.",
    difficulty: "Beginner",
    totalWeeks: 4,
    recommendedExperience: "This block is for everyone.",
    equipmentNeeded: [
      "Adjustable cable machine",
      "Dumbbells",
      "Barbell",
      "Plates",
      "Adjustable bench",
      "Rack"
    ],
    scheduleImage: "${baseSchedulePath}MWF_cal_BG.png",
    mainImage: "${baseImagePath}PushPullLegsPlus.jpg",
    liftList: [
      "Incline Bench Press",
      "Seated DB Shoulder Press",
      "Bench Press",
      "Lateral Raises",
    ],
  ),
];
