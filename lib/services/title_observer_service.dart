import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/leaderboard_service.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/timeline_service.dart';


class TitleObserverService {
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  static String? _lastTitle;
  static String? _lastName;
  static String? _lastProfileUrl;

  static void startObservingTitle() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    _subscription = userDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      final newTitle = data['title'];
      final newName = data['displayName'];
      final newUrl = data['profileImageUrl'];

      if (newTitle != _lastTitle || newName != _lastName || newUrl != _lastProfileUrl) {
        await TimelineService.updateUserInfo(
          userId: userId,
          displayName: newName,
          profileImageUrl: newUrl,
          title: newTitle,
        );
      }

      _lastTitle = newTitle;
      _lastName = newName;
      _lastProfileUrl = newUrl;

      // Step 1: Find all blockIds where user has leaderboard entries
      final blocks = await _getUserBlockIds(userId);

      for (final blockId in blocks) {
        await syncBestLeaderboardEntryForBlock(userId: userId, blockId: blockId);
      }

      print('🔄 Title changed, resynced all leaderboards for user $userId.');
    });
  }

  static void stopObserving() {
    _subscription?.cancel();
    _subscription = null;
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
