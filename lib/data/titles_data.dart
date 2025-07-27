final List<String> titles = [
  'Newb'
  'Lone Wolf',
  'Iron Hatchling',
  'Plate Apprentice',
  'Barbell Acolyte',
  'Soldier of Steel',
  'Lift Enforcer',
  'Set Mercenary',
  'Rep Warden',
  'Gym Lieutenant',
  'Loadbearer',
  'Swolebringer',
  'League Champion',
  'Block Master',
  'Sun Eater',
  'God Among Titans',
];

final List<int> titleMilestones = [0,1,2,3,4,5,6,7,8,9,10,11,12,18,24,36];

int getUserTitleIndex(int blocksCompleted) {
  for (int i = titleMilestones.length - 1; i >= 0; i--) {
    if (blocksCompleted >= titleMilestones[i]) return i;
  }
  return 0;
}

String getUserTitle(int blocksCompleted) {
  final index = getUserTitleIndex(blocksCompleted);
  return titles[index];
}
