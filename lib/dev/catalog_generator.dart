// lib/dev/catalog_generator.dart
// Run with: dart run lib/dev/catalog_generator.dart
// Outputs JSON to console and writes /assets/lift_catalog.generated.json

import 'dart:convert';
import 'dart:io';

/// ====== 1) PASTE your raw list here (one per line) ======
/// Tip: keep only actual lift names; remove section headers.
const rawNames = r'''
Assisted Dip
Band-Assisted Bench Press
Bar Dip
Bench Press
Bench Press Against Band
Board Press
Cable Chest Press
Clap Push-Up
Close-Grip Bench Press
Close-Grip Feet-Up Bench Press
Decline Bench Press
Decline Push-Up
Dumbbell Chest Fly
Dumbbell Chest Press
Dumbbell Decline Chest Press
Dumbbell Floor Press
Dumbbell Pullover
Feet-Up Bench Press
Floor Press
Incline Bench Press
Incline Dumbbell Press
Incline Push-Up
Kettlebell Floor Press
Kneeling Incline Push-Up
Kneeling Push-Up
Machine Chest Fly
Machine Chest Press
Pec Deck
Pin Bench Press
Plank to Push-Up
Push-Up
Push-Up Against Wall
Push-Ups With Feet in Rings
Resistance Band Chest Fly
Ring Dip
Seated Cable Chest Fly
Smith Machine Bench Press
Smith Machine Incline Bench Press
Smith Machine Reverse Grip Bench Press
Standing Cable Chest Fly
Standing Resistance Band Chest Fly
Arnold Press
Band External Shoulder Rotation
Band Internal Shoulder Rotation
Band Pull-Apart
Banded Face Pull
Barbell Front Raise
Barbell Rear Delt Row
Barbell Upright Row
Behind the Neck Press
Cable Internal Shoulder Rotation
Cable Front Raise
Cable Lateral Raise
Cable Rear Delt Row
Cuban Press
Devils Press
Dumbbell Front Raise
Dumbbell Horizontal Internal Shoulder Rotation
Dumbbell Horizontal External Shoulder Rotation
Dumbbell Lateral Raise
Dumbbell Rear Delt Row
Dumbbell Shoulder Press
Face Pull
Front Hold
Handstand Push-Up
Jerk
Kettlebell Halo
Landmine Press
Lying Dumbbell External Shoulder Rotation
Lying Dumbbell Internal Shoulder Rotation
Machine Lateral Raise
Machine Shoulder Press
Monkey Row
One-Arm Landmine Press
Overhead Press
Plate Front Raise
Poliquin Raise
Power Jerk
Push Press
Resistance Band Lateral Raise
Reverse Cable Flyes
Reverse Dumbbell Flyes
Reverse Machine Fly
Seated Dumbbell Shoulder Press
Seated Barbell Overhead Press
Seated Kettlebell Press
Seated Smith Machine Shoulder Press
Snatch Grip Behind the Neck Press
Squat Jerk
Split Jerk
Wall Walk
Barbell Curl
Barbell Preacher Curl
Bayesian Curl
Bodyweight Curl
Cable Crossover Bicep Curl
Cable Curl With Bar
Cable Curl With Rope
Concentration Curl
Drag Curl
Dumbbell Curl
Dumbbell Preacher Curl
Hammer Curl
Incline Dumbbell Curl
Machine Bicep Curl
Resistance Band Curl
Spider Curl
Zottman Curl
Barbell Standing Triceps Extension
Barbell Incline Triceps Extension
Barbell Lying Triceps Extension
Bench Dip
Crossbody Cable Triceps Extension
Close-Grip Push-Up
Dumbbell Lying Triceps Extension
Dumbbell Standing Triceps Extension
Overhead Cable Triceps Extension
Tate Press
Tricep Bodyweight Extension
Tricep Pushdown With Bar
Tricep Pushdown With Rope
Air Squat
Banded Hip March
Barbell Hack Squat
Barbell Lunge
Barbell Walking Lunge
Belt Squat
Body Weight Lunge
Bodyweight Leg Curl
Box Jump
Box Squat
Bulgarian Split Squat
Cable Machine Hip Adduction
Chair Squat
Curtsy Lunge
Dumbbell Lunge
Dumbbell Walking Lunge
Dumbbell Squat
Front Squat
Glute Ham Raise
Goblet Squat
Hack Squat Machine
Half Air Squat
Hip Adduction Against Band
Hip Adduction Machine
Jumping Lunge
Kettlebell Thrusters
Landmine Hack Squat
Landmine Squat
Lateral Bound
Leg Curl On Ball
Leg Extension
Leg Press
Lying Leg Curl
Nordic Hamstring Eccentric
One-Legged Leg Extension
One-Legged Lying Leg Curl
One-Legged Seated Leg Curl
Pause Squat
Pin Squat
Pistol Squat
Poliquin Step-Up
Prisoner Get Up
Reverse Barbell Lunge
Reverse Body Weight Lunge
Reverse Dumbbell Lunge
Reverse Nordic
Romanian Deadlift
Safety Bar Squat
Seated Leg Curl
Shallow Body Weight Lunge
Side Lunges (Bodyweight)
Smith Machine Bulgarian Split Squat
Smith Machine Front Squat
Smith Machine Squat
Sumo Squat
Squat
Standing Cable Leg Extension
Standing Hip Flexor Raise
Step Up
Tibialis Raise
Zercher Squat
Zombie Squat
Assisted Chin-Up
Assisted Pull-Up
Back Extension
Banded Muscle-Up
Barbell Row
Barbell Shrug
Block Clean
Block Snatch
Cable Close Grip Seated Row
Cable Wide Grip Seated Row
Chest to Bar
Chin-Up
Clean
Clean and Jerk
Close-Grip Chin-Up
Close-Grip Lat Pulldown
Deadlift
Deficit Deadlift
Dumbbell Deadlift
Dumbbell Row
Dumbbell Shrug
Floor Back Extension
Good Morning
Gorilla Row
Hang Clean
Hang Power Clean
Hang Power Snatch
Hang Snatch
Inverted Row
Inverted Row with Underhand Grip
Jefferson Curl
Jumping Muscle-Up
Kettlebell Clean
Kettlebell Clean & Jerk
Kettlebell Clean & Press
Kettlebell Swing
Kroc Row
Lat Pulldown With Pronated Grip
Lat Pulldown With Supinated Grip
Muscle-Up (Bar)
Muscle-Up (Rings)
Neutral Close-Grip Lat Pulldown
One-Handed Cable Row
One-Handed Kettlebell Swing
One-Handed Lat Pulldown
Pause Deadlift
Pendlay Row
Power Clean
Power Snatch
Pull-Up
Pull-Up With a Neutral Grip
Rack Pull
Renegade Row
Ring Pull-Up
Ring Row
Scap Pull-Up
Seal Row
Seated Machine Row
Single Leg Deadlift with Kettlebell
Smith Machine One-Handed Row
Snatch
Snatch Grip Deadlift
Stiff-Legged Deadlift
Straight Arm Lat Pulldown
Sumo Deadlift
Superman Raise
T-Bar Row
Towel Row
Trap Bar Deadlift With High Handles
Trap Bar Deadlift With Low Handles
Banded Side Kicks
Cable Pull Through
Cable Machine Hip Abduction
Clamshells
Cossack Squat
Death March with Dumbbells
Donkey Kicks
Dumbbell Romanian Deadlift
Dumbbell Frog Pumps
Fire Hydrants
Frog Pumps
Glute Bridge
Hip Abduction Against Band
Hip Abduction Machine
Hip Thrust
Hip Thrust Machine
Hip Thrust With Band Around Knees
Kettlebell Windmill
Lateral Walk With Band
Machine Glute Kickbacks
One-Legged Glute Bridge
One-Legged Hip Thrust
Reverse Hyperextension
Romanian Deadlift
Smith Machine Hip Thrust
Single Leg Romanian Deadlift
Standing Hip Abduction Against Band
Standing Glute Kickback in Machine
Standing Glute Push Down
Step Up
Ball Slams
Bicycle Crunch
Cable Crunch
Copenhagen Plank
Core Twist
Crunch
Dead Bug
Dead Bug With Dumbbells
Dragon Flag
Dumbbell Side Bend
Hanging Knee Raise
Hanging Leg Raise
Hanging Sit-Up
Hanging Windshield Wiper
High to Low Wood Chop with Band
High to Low Wood Chop with Cable
Hollow Body Crunch
Hollow Hold
Horizontal Wood Chop with Band
Horizontal Wood Chop with Cable
Jackknife Sit-Up
Kettlebell Plank Pull Through
Kneeling Ab Wheel Roll-Out
Kneeling Plank
Kneeling Side Plank
L-Sit
Lying Leg Raise
Lying Windshield Wiper
Lying Windshield Wiper with Bent Knees
Machine Crunch
Mountain Climbers
Oblique Crunch
Oblique Sit-Up
Plank
Plank with Leg Lifts
Plank with Shoulder Taps
Side Plank
Sit-Up
Weighted Plank
Barbell Standing Calf Raise
Barbell Seated Calf Raise
Donkey Calf Raise
Eccentric Heel Drop
Heel Raise
Seated Calf Raise
Standing Calf Raise
Barbell Wrist Curl
Barbell Wrist Curl Behind the Back
Bar Hang
Dumbbell Wrist Curl
Farmers Walk
Fat Bar Deadlift
Gripper
One-Handed Bar Hang
Plate Pinch
Plate Wrist Curl
Towel Pull-Up
Wrist Roller
Barbell Wrist Extension
Dumbbell Wrist Extension
Lying Neck Curl
Lying Neck Extension
''';

/// ====== 2) Basic enums/labels ======
const groups = <String>{
  'Chest','Shoulder','Back','Legs','Glute','Biceps','Triceps','Abs','Calves','Forearm','Neck'
};

/// ====== 3) Heuristics ======
/// You can adjust these without touching the core logic.

String detectEquipment(String n) {
  final name = n.toLowerCase();

  if (name.contains('smith machine')) return 'Smith Machine';
  if (name.contains('trap bar')) return 'Trap Bar';
  if (name.contains('landmine')) return 'Landmine';
  if (name.contains('kettlebell')) return 'Kettlebell';
  if (name.contains('dumbbell')) return 'Dumbbell';
  if (name.contains('barbell')) return 'Barbell';
  if (name.contains('plate ') || name.startsWith('plate ')) return 'Plate';
  if (name.contains('cable') || name.contains('lat pulldown')) return 'Cable';
  if (name.contains('machine') || name.contains('pec deck') || name.contains('hack squat machine'))
    return 'Machine';
  if (name.contains('band') || name.contains('resistance band')) return 'Band';
  if (name.contains('ring') || name.contains('rings')) return 'Rings';
  if (name.contains('bodyweight') || name.contains('push-up') || name.contains('pull-up') ||
      name.contains('chin-up') || name.contains('sit-up') || name.contains('plank') ||
      name.contains('l-sit') || name.contains('air squat') || name.contains('pistol squat') ||
      name.contains('hollow') || name.contains('dragon flag') || name.contains('wall walk') ||
      name.contains('mountain climbers') || name.contains('bar hang') || name.contains('towel pull-up'))
    return 'Bodyweight';
  if (name.contains('sled')) return 'Sled';

  // Rows/press without qualifier often default to Barbell in this ecosystem
  if (name.contains('press') || name.contains('row') || name.contains('deadlift') ||
      name.contains('squat') || name.contains('clean') || name.contains('snatch') ||
      name.contains('good morning') || name.contains('shrug'))
    return 'Barbell';

  // Default fallback
  return 'Machine';
}

bool isBodyweight(String n, String equipment) {
  final name = n.toLowerCase();
  if (equipment == 'Bodyweight' || name.contains('push-up') || name.contains('pull-up') ||
      name.contains('chin-up') || name.contains('sit-up') || name.contains('plank') ||
      name.contains('l-sit') || name.contains('dragon flag') || name.contains('wall walk') ||
      name.contains('air squat') || name.contains('pistol squat') || name.contains('hollow') ||
      name.contains('mountain climbers') || name.contains('bar hang') || name.contains('towel pull-up'))
    return true;
  // Assisted variants are still bodyweight-primary
  if (name.contains('assisted pull-up') || name.contains('assisted chin-up') || name.contains('assisted dip'))
    return true;
  return false;
}

bool isDumbbellPrimary(String n, String equipment) {
  final name = n.toLowerCase();
  if (equipment == 'Dumbbell') return true;
  // Moves that are *commonly* DB even without the word
  if (name.contains('concentration curl') || name.contains('tate press') || name.contains('farmer'))
    return true;
  return false;
}

bool isUnilateral(String n) {
  final name = n.toLowerCase();
  if (name.contains('one-arm') || name.contains('one-handed') || name.contains('single arm') ||
      name.contains('single-leg') || name.contains('one-legged') || name.contains('unilateral'))
    return true;

  // Typical unilateral patterns by movement name:
  if (name.contains('lunge') || name.contains('step up') || name.contains('step-up') ||
      name.contains('split squat') || name.contains('curtsy') || name.contains('windmill') ||
      name.contains('side bend') || name.contains('halo'))
    return true;

  // Rows generally bilateral unless specified:
  return false;
}

String detectPrimaryGroup(String n) {
  final name = n.toLowerCase();

  // Upper body pushes
  if (name.contains('bench') || name.contains('push-up') || name.contains('chest press') ||
      name.contains('chest fly') || name.contains('pec deck') || name.contains('dip'))
    return 'Chest';

  if (name.contains('overhead press') || name.contains('shoulder press') ||
      name.contains('lateral raise') || name.contains('front raise') ||
      name.contains('rear delt') || name.contains('upright row') ||
      name.contains('face pull') || name.contains('jerk') || name.contains('push press') ||
      name.contains('behind the neck press') || name.contains('snatch grip behind the neck press') ||
      name.contains('arnold press') || name.contains('cuban press') || name.contains('monkey row') ||
      name.contains('landmine press') || name.contains('plate front raise') ||
      name.contains('poliquin raise'))
    return 'Shoulder';

  // Pulls / back
  if (name.contains('row') || name.contains('pull-up') || name.contains('chin-up') ||
      name.contains('lat pulldown') || name.contains('t-bar') || name.contains('seal row') ||
      name.contains('renegade row') || name.contains('inverted row') || name.contains('good morning') ||
      name.contains('shrug') || name.contains('back extension') || name.contains('scap pull-up') ||
      name.contains('straight arm lat pulldown') || name.contains('superman raise') ||
      name.contains('gorilla row') || name.contains('kroc row') || name.contains('towel row'))
    return 'Back';

  // Arms
  if (name.contains('curl') && !name.contains('leg')) return 'Biceps';
  if (name.contains('tricep') || name.contains('triceps') || name.contains('pushdown') ||
      (name.contains('extension') && name.contains('lying') && !name.contains('leg')))
    return 'Triceps';

  // Hinge patterns lean Glute/Hamstring primary (project convention)
  if (name.contains('deadlift') || name.contains('rdl') || name.contains('romanian deadlift') ||
      name.contains('hip thrust') || name.contains('pull through') || name.contains('glute') ||
      name.contains('reverse hyper') || name.contains('good morning') || name.contains('hamstring'))
    return 'Glute';

  // Squats / lunges / leg curls/extensions default to Legs
  if (name.contains('squat') || name.contains('lunge') || name.contains('leg press') ||
      name.contains('leg curl') || name.contains('leg extension') || name.contains('step up') ||
      name.contains('hack squat') || name.contains('zercher') || name.contains('belt squat') ||
      name.contains('pause squat') || name.contains('pin squat') || name.contains('chair squat'))
    return 'Legs';

  // Abs / Core
  if (name.contains('plank') || name.contains('sit-up') || name.contains('crunch') ||
      name.contains('leg raise') || name.contains('wood chop') || name.contains('dead bug') ||
      name.contains('l-sit') || name.contains('hollow') || name.contains('jackknife') ||
      name.contains('dragon flag') || name.contains('windshield wiper') || name.contains('mountain climbers') ||
      name.contains('kettlebell plank pull through') || name.contains('core twist'))
    return 'Abs';

  // Calves
  if (name.contains('calf raise') || name.contains('heel drop') || name.contains('heel raise'))
    return 'Calves';

  // Forearms & grip
  if (name.contains('wrist') || name.contains('grip') || name.contains('bar hang') ||
      name.contains('plate pinch') || name.contains('towel pull-up') || name.contains('wrist roller') ||
      name.contains('farmers walk') || name.contains('fat bar deadlift'))
    return 'Forearm';

  // Neck
  if (name.contains('neck')) return 'Neck';

  // Olympic lifts — default to Back (posterior chain + upper back),
  // but you can move these to 'Glute' if you prefer.
  if (name.contains('clean') || name.contains('snatch')) return 'Back';

  // Fallback
  return 'Back';
}

/// ====== 4) Manual overrides for tricky cases (edit as needed) ======
class Override {
  final String? primaryGroup;
  final String? equipment;
  final bool? isBodyweight;
  final bool? isDumbbell;
  final bool? unilateral;
  const Override({this.primaryGroup, this.equipment, this.isBodyweight, this.isDumbbell, this.unilateral});
}

// Example: move Goblet Squat to Dumbbell equipment explicitly
final Map<String, Override> overrides = {
  'Goblet Squat': Override(equipment: 'Dumbbell', unilateral: false, primaryGroup: 'Legs'),
  'Devils Press': Override(equipment: 'Dumbbell', primaryGroup: 'Shoulder'),
  'Farmers Walk': Override(equipment: 'Dumbbell', primaryGroup: 'Forearm', unilateral: false),
  'Dead Bug With Dumbbells': Override(equipment: 'Dumbbell', primaryGroup: 'Abs'),
  'Single Leg Deadlift with Kettlebell': Override(equipment: 'Kettlebell', unilateral: true, primaryGroup: 'Glute'),
  'Ring Dip': Override(equipment: 'Rings', primaryGroup: 'Chest', isBodyweight: true),
  'Ring Row': Override(equipment: 'Rings', primaryGroup: 'Back', isBodyweight: true),
};

/// ====== 5) Generation ======
Map<String, dynamic> toEntry(String original) {
  final name = original.trim();
  if (name.isEmpty) return {};
  final ov = overrides[name];

  final equipment = ov?.equipment ?? detectEquipment(name);
  final body = ov?.isBodyweight ?? isBodyweight(name, equipment);
  final dbell = ov?.isDumbbell ?? isDumbbellPrimary(name, equipment);
  final uni = ov?.unilateral ?? isUnilateral(name);
  final group = ov?.primaryGroup ?? detectPrimaryGroup(name);

  return {
    'name': name,
    'primaryGroup': groups.contains(group) ? group : 'Back',
    'secondaryGroups': null, // or [] if you want to store as JSON
    'equipment': equipment,
    'isBodyweightCapable': body ? 1 : 0,
    'isDumbbellCapable': dbell ? 1 : 0,
    'unilateral': uni ? 1 : 0,
    'youtubeUrl': null,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };

}

void main() async {
  final names = rawNames
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
  // strip obvious section headers if any slipped through
      .where((s) => !RegExp(r'Exercises$', caseSensitive: false).hasMatch(s))
      .toList();

  final entries = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (final n in names) {
    if (seen.contains(n.toLowerCase())) continue;
    seen.add(n.toLowerCase());
    final e = toEntry(n);
    if (e.isNotEmpty) entries.add(e);
  }

  // Pretty print to console
  final out = const JsonEncoder.withIndent('  ').convert(entries);
  stdout.writeln(out);

  // Also write to assets for app seeding
  final file = File('assets/lift_catalog.generated.json');
  await file.create(recursive: true);
  await file.writeAsString(out);
  stdout.writeln('\nWrote ${entries.length} entries to assets/lift_catalog.generated.json');
}
