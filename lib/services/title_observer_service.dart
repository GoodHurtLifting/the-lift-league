import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/leaderboard_service.dart';
import 'package:lift_league/services/db_service.dart';

class TitleObserverService {
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? _listener;

  static void startObservingTitle() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    _listener = userDoc.snapshots();
    _listener?.listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      // Step 1: Find all blockIds where user has leaderboard entries
      final blocks = await _getUserBlockIds(userId);

      for (final blockId in blocks) {
        await syncBestLeaderboardEntryForBlock(userId: userId, blockId: blockId);
      }

      print('🔄 Title changed, resynced all leaderboards for user $userId.');
    });
  }

  static void stopObserving() {
    _listener = null;
  }

  static Future<List<int>> _getUserBlockIds(String userId) async {
    final db = DBService();
    final dbInstance = await db.database;

    final results = await dbInstance.rawQuery('''
      SELECT DISTINCT blockId
      FROM block_totals
      WHERE userId = ?
    ''', [userId]);

    return results.map((row) => row['blockId'] as int).toList();
  }
}
