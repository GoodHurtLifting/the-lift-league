import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/utils/workout_utils.dart';

Future<void> syncBestLeaderboardEntryForBlock({
  required String userId,
  required int blockId,
}) async {
  final db = DBService();
  final firestore = FirebaseFirestore.instance;

  // Step 1: Find the best blockInstance for this block
  final leaderboardData = await db.getLeaderboardDataForBlock(blockId);

  final userEntry = leaderboardData.firstWhere(
        (e) => e['userId'] == userId,
    orElse: () => {},
  );

  if (userEntry.isEmpty) {
    print("❌ No best block found for user $userId in block $blockId");
    return;
  }

  final int blockInstanceId = int.tryParse(userEntry['blockInstanceId'].toString()) ?? 0;
  if (blockInstanceId == 0) {
    print("❌ No valid blockInstanceId found for leaderboard sync.");
    return;
  }

  // Step 2: Get all workout instances inside that block instance
  final workouts = await db.getWorkoutInstancesByBlock(blockInstanceId);

  // Step 3: Gather best score by workoutName
  final Map<String, double> bestScoresByName = {};

  for (final workout in workouts) {
    final int workoutInstanceId = workout['workoutInstanceId'];
    final String workoutName = (workout['workoutName'] ?? '').toString().trim();

    if (workoutName.toLowerCase().contains('recovery')) continue;

    final totals = await db.getWorkoutTotals(workoutInstanceId, userId);
    final double workoutScore = (totals?['workoutScore'] as num?)?.toDouble() ?? 0.0;

    if (!bestScoresByName.containsKey(workoutName) || workoutScore > bestScoresByName[workoutName]!) {
      bestScoresByName[workoutName] = workoutScore;
    }
  }

// new:
  final sortedWorkoutNames = getOrderedWorkoutNamesForBlock(blockId).where((name) =>
      bestScoresByName.keys.any((key) => key.toLowerCase().contains(name.toLowerCase()))
  ).toList();

  final List<double> bestScoreList = sortedWorkoutNames
      .map((name) => bestScoresByName[name] ?? 0.0)
      .toList();

  final List<String> workoutScores = bestScoreList.map((score) => score.toStringAsFixed(1)).toList();

  final double blockScore = bestScoreList.fold(0.0, (a, b) => a + b);

  // Step 5: Fetch user profile info
  final userDoc = await firestore.collection('users').doc(userId).get();
  final userData = userDoc.data() ?? {};

  final leaderboardEntry = {
    'displayName': userData['displayName'] ?? 'Anonymous',
    'profileImageUrl': userData['profileImageUrl'] ?? '',
    'title': userData['title'] ?? '',
    'blockScore': blockScore,
    'workoutScores': workoutScores,
  };

  // Step 6: Write or update leaderboard entry
  final entryRef = firestore
      .collection('leaderboards')
      .doc(blockId.toString())
      .collection('entries')
      .doc(userId);

  await entryRef.set(leaderboardEntry, SetOptions(merge: true));

  print("✅ Synced leaderboard for user $userId | Block $blockId | Score $blockScore");
}



Future<Map<String, dynamic>> getBestBlockStatsForUser({
  required String userId,
  required int blockId,
}) async {
  final db = await DBService().database;

  // Step 1: Get user's best blockInstanceId for this blockId
  final bestInstance = await db.rawQuery('''
    SELECT blockInstanceId, blockScore
    FROM block_totals
    WHERE userId = ? AND blockId = ?
    ORDER BY blockScore DESC
    LIMIT 1
  ''', [userId, blockId]);

  if (bestInstance.isEmpty) {
    throw Exception('No block data found for user.');
  }

  final blockInstanceId = bestInstance.first['blockInstanceId'] as int;
  final blockScore = (bestInstance.first['blockScore'] as num?)?.toDouble() ?? 0.0;

  // Step 2: Get workout scores for that blockInstance
  final workoutScoresRaw = await db.rawQuery('''
    SELECT workoutScore FROM workout_totals
    WHERE blockInstanceId = ?
  ''', [blockInstanceId]);

  final workoutScores = workoutScoresRaw
      .map((e) => (e['workoutScore'] as num?)?.toDouble() ?? 0.0)
      .toList();

  return {
    'blockInstanceId': blockInstanceId,
    'blockScore': blockScore,
    'workoutScores': workoutScores,
  };
}
