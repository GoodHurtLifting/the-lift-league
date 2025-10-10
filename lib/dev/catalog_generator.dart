// lib/dev/catalog_generator.dart
// Run with: dart run lib/dev/catalog_generator.dart
// Outputs JSON to console and writes /assets/lift_catalog.generated.json

import 'dart:convert';
import 'dart:io';

/// ====== 1) PASTE your raw list here (one per line) ======
/// Tip: keep only actual lift names; remove section headers.
const rawNames = r'''
Air Squat
Arnold Press
Assisted Chin-Up
Assisted Dip
Assisted Pull-Up
Back Extension
Banded Face Pull
Banded Hip March
Banded Muscle-Up
Banded Side Kicks
Band External Shoulder Rotation
Band Internal Shoulder Rotation
Band Pull-Apart
Band-Assisted Bench Press
Bar Dip
Bar Hang
Barbell Curl
Barbell Front Raise
Barbell Hack Squat
Barbell Lunge
Barbell Preacher Curl
Barbell Rear Delt Row
Barbell Row
Barbell Seated Calf Raise
Barbell Shrug
Barbell Standing Calf Raise
Barbell Standing Triceps Extension
Barbell Upright Row
Barbell Wrist Curl
Barbell Wrist Curl Behind the Back
Barbell Wrist Extension
Bayesian Curl
Belt Squat
Bench Dip
Bench Press
Bench Press Against Band
Bicycle Crunch
Block Clean
Block Snatch
Board Press
Body Weight Lunge
Bodyweight Curl
Bodyweight Leg Curl
Box Jump
Box Squat
Bulgarian Split Squat
Cable Chest Press
Cable Close Grip Seated Row
Cable Crossover Bicep Curl
Cable Crunch
Cable Front Raise
Cable Internal Shoulder Rotation
Cable Lateral Raise
Cable Machine Hip Abduction
Cable Machine Hip Adduction
Cable Pull Through
Cable Rear Delt Row
Cable Wide Grip Seated Row
Chair Squat
Chest to Bar
Chin-Up
Clamshells
Clap Push-Up
Clean
Clean and Jerk
Close-Grip Bench Press
Close-Grip Chin-Up
Close-Grip Feet-Up Bench Press
Close-Grip Lat Pulldown
Close-Grip Push-Up
Concentration Curl
Core Twist
Cossack Squat
Crunch
Crossbody Cable Triceps Extension
Cuban Press
Curtsy Lunge
Dead Bug
Dead Bug With Dumbbells
Deadlift
Decline Bench Press
Decline Push-Up
Deficit Deadlift
Death March with Dumbbells
Devils Press
Donkey Calf Raise
Donkey Kicks
Drag Curl
Dumbbell Chest Fly
Dumbbell Curl
Dumbbell Decline Chest Press
Dumbbell Floor Press
Dumbbell Frog Pumps
Dumbbell Front Raise
Dumbbell Horizontal External Shoulder Rotation
Dumbbell Horizontal Internal Shoulder Rotation
Dumbbell Lateral Raise
Dumbbell Lying Triceps Extension
Dumbbell Plank Pull Through
Dumbbell Preacher Curl
Dumbbell Pullover
Dumbbell Rear Delt Row
Dumbbell Romanian Deadlift
Dumbbell Row
Dumbbell Shoulder Press
Dumbbell Side Bend
Dumbbell Squat
Dumbbell Standing Triceps Extension
Dumbbell Walking Lunge
Eccentric Heel Drop
Face Pull
Farmers Walk
Fat Bar Deadlift
Feet-Up Bench Press
Fire Hydrants
Floor Back Extension
Floor Press
Front Hold
Front Squat
Goblet Squat
Good Morning
Gorilla Row
Gripper
Hack Squat Machine
Hammer Curl
Handstand Push-Up
Hang Clean
Hang Power Clean
Hang Power Snatch
Hang Snatch
Hanging Knee Raise
Hanging Leg Raise
Hanging Sit-Up
Hanging Windshield Wiper
Heel Raise
High to Low Wood Chop with Band
High to Low Wood Chop with Cable
Hip Abduction Against Band
Hip Abduction Machine
Hip Adduction Against Band
Hip Adduction Machine
Hip Thrust
Hip Thrust Machine
Hip Thrust With Band Around Knees
Hollow Body Crunch
Hollow Hold
Horizontal Wood Chop with Band
Horizontal Wood Chop with Cable
Incline Bench Press
Incline Dumbbell Curl
Incline Dumbbell Press
Incline Push-Up
Inverted Row
Inverted Row with Underhand Grip
Jackknife Sit-Up
Jefferson Curl
Jerk
Jumping Lunge
Jumping Muscle-Up
Kettlebell Clean
Kettlebell Clean & Jerk
Kettlebell Clean & Press
Kettlebell Floor Press
Kettlebell Halo
Kettlebell Plank Pull Through
Kettlebell Swing
Kettlebell Thrusters
Kettlebell Windmill
Kneeling Ab Wheel Roll-Out
Kneeling Incline Push-Up
Kneeling Plank
Kneeling Push-Up
Kneeling Side Plank
Kroc Row
L-Sit
Landmine Hack Squat
Landmine Press
Landmine Squat
Lateral Bound
Lateral Walk With Band
Lat Pulldown With Pronated Grip
Lat Pulldown With Supinated Grip
Leg Extension
Leg Press
Leg Curl On Ball
Lying Dumbbell External Shoulder Rotation
Lying Dumbbell Internal Shoulder Rotation
Lying Leg Raise
Lying Leg Curl
Lying Neck Curl
Lying Neck Extension
Lying Windshield Wiper
Lying Windshield Wiper with Bent Knees
Machine Bicep Curl
Machine Chest Fly
Machine Chest Press
Machine Crunch
Machine Glute Kickbacks
Machine Lateral Raise
Machine Shoulder Press
Monkey Row
Mountain Climbers
Muscle-Up (Bar)
Muscle-Up (Rings)
Neutral Close-Grip Lat Pulldown
Nordic Hamstring Eccentric
Oblique Crunch
Oblique Sit-Up
One-Arm Landmine Press
One-Handed Bar Hang
One-Handed Cable Row
One-Handed Kettlebell Swing
One-Handed Lat Pulldown
One-Legged Glute Bridge
One-Legged Hip Thrust
One-Legged Leg Extension
One-Legged Lying Leg Curl
One-Legged Seated Leg Curl
Overhead Cable Triceps Extension
Overhead Press
Pause Deadlift
Pause Squat
Pec Deck
Pendlay Row
Pistol Squat
Plate Front Raise
Plate Pinch
Plate Wrist Curl
Plank
Plank to Push-Up
Plank with Leg Lifts
Plank with Shoulder Taps
Poliquin Raise
Poliquin Step-Up
Power Clean
Power Jerk
Power Snatch
Prisoner Get Up
Push Press
Push-Up
Push-Up Against Wall
Push-Ups With Feet in Rings
Rack Pull
Renegade Row
Resistance Band Chest Fly
Resistance Band Curl
Resistance Band Lateral Raise
Reverse Barbell Lunge
Reverse Cable Flyes
Reverse Dumbbell Flyes
Reverse Hyperextension
Reverse Machine Fly
Reverse Nordic
Ring Dip
Ring Pull-Up
Ring Row
Romanian Deadlift
Row Bent Over
Scap Pull-Up
Seal Row
Seated Barbell Overhead Press
Seated Cable Chest Fly
Seated Dumbbell Shoulder Press
Seated Leg Curl
Seated Machine Row
Seated Smith Machine Shoulder Press
Side Lunges (Bodyweight)
Side Plank
Single Leg Deadlift with Kettlebell
Single Leg Romanian Deadlift
Smith Machine Bench Press
Smith Machine Bulgarian Split Squat
Smith Machine Front Squat
Smith Machine Hip Thrust
Smith Machine Incline Bench Press
Smith Machine One-Handed Row
Smith Machine Reverse Grip Bench Press
Smith Machine Squat
Snatch
Snatch Grip Behind the Neck Press
Snatch Grip Deadlift
Spider Curl
Split Jerk
Squat
Squat Jerk
Stiff-Legged Deadlift
Straight Arm Lat Pulldown
Standing Cable Leg Extension
Standing Calf Raise
Standing Glute Kickback in Machine
Standing Glute Push Down
Standing Hip Abduction Against Band
Standing Hip Flexor Raise
Step Up
Sumo Deadlift
Sumo Squat
Superman Raise
T-Bar Row
Tate Press
Tibialis Raise
Toes-To-Bar
Towel Pull-Up
Towel Row
Trap Bar Deadlift With High Handles
Trap Bar Deadlift With Low Handles
Tricep Bodyweight Extension
Tricep Pushdown With Bar
Tricep Pushdown With Rope
Wall Walk
Weighted Plank
Wrist Roller
Zercher Squat
Zombie Squat
Abs Ball Crunches
Back Extension (Hamstrings Focused)
Cable Lateral Raise (Split Stance)
Calf Raises Landmine
Calf Raises Smith
Delt Forward Raises
Delt Front Raise Cable
Delt Lateral Raises
Delt Rear Cross Cable Fly
Dumbbell Kickback
Good Mornings Smith
Hip Abduction (Unspecified)
Hip Adduction (Unspecified)
Lat Pulldown (Unspecified Grip)
Leg Press Single Leg
Lunges Forward
Lunges Reverse
Pec Flys DB
Press Arnold
Press Bench
Press Decline
Press DB Overhead Alternating
Press High Low Cable Fly
Press Incline
Press Incline DB
Press Low High Cable Fly
Press Overhead
Press Push Ups
Row DB Incline
Row Inverted
Row Reverse Grip Barbell
Row Seated Cable
Row Seated Cable Single Arm
Row Seated Cable Wide Grip
Row Single Arm DB
Row T Bar
Row Upright Wide Grip
Shrugs Barbell
Shrugs DB
Shrugs BB
Tricep Ext French Press
Tricep Ext OH Cable
Tricep Ext OH DB
Tricep Ext Reverse Grip
Tricep Kickbacks DB
Tricep Push Downs Rope
Tricep Push Downs Straight Bar
Tricep Skull Crushers

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
  if (name.contains('one-arm') || name.contains('one-handed') || name.contains('wood chop') || name.contains('single arm') ||
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
