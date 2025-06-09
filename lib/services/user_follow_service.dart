import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class UserFollowService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final now = Timestamp.now();
    try {
      print('[followUser] Start: $currentUserId wants to follow $targetUserId');

      // Add to following
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .set({'timestamp': now});
      print('[followUser] Added to following');

      // Add to followers
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .set({'timestamp': now});
      print('[followUser] Added to followers');

      // Notify the user who was followed
      final currentUserDoc =
      await _firestore.collection('users').doc(currentUserId).get();
      final fromName = currentUserDoc.data()?['displayName'] ?? 'Someone';

      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
        'type': 'follow',
        'fromUserId': currentUserId,
        'fromDisplayName': fromName,
        'timestamp': now,
        'seen': false,
      });
      print('[followUser] Notification sent');
    } catch (e, stack) {
      print('[followUser] Error: $e');
      await FirebaseCrashlytics.instance.recordError(e, stack, reason: 'followUser failed');
      rethrow;
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .delete();

    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .delete();
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .get();
    return doc.exists;
  }

  Future<void> addToTrainingCircle(String currentUserId, Map<String, dynamic> userData) async {
    try {
      print('[addToTrainingCircle] Start: $currentUserId adding ${userData['userId']}');
      final circleRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('training_circle');

      final snapshot = await circleRef.get();
      print('[addToTrainingCircle] Current size: ${snapshot.size}');
      if (snapshot.size >= 10) {
        print('[addToTrainingCircle] Limit reached');
        return; // Limit to 10 members
      }

      await circleRef.doc(userData['userId']).set({
        'displayName': userData['displayName'],
        'profileImageUrl': userData['profileImageUrl'],
        'title': userData['title'],
        'timestamp': Timestamp.now(),
      });
      print('[addToTrainingCircle] User added to training circle');

      // Notify the user who was added to the circle
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final fromName = currentUserDoc.data()?['displayName'] ?? 'Someone';

      await _firestore
          .collection('users')
          .doc(userData['userId'])
          .collection('notifications')
          .add({
        'type': 'training_circle_add',
        'fromUserId': currentUserId,
        'fromDisplayName': fromName,
        'timestamp': Timestamp.now(),
        'seen': false,
      });
      print('[addToTrainingCircle] Notification sent');
    } catch (e, stack) {
      print('[addToTrainingCircle] Error: $e');
      await FirebaseCrashlytics.instance.recordError(e, stack, reason: 'addToTrainingCircle failed');
      rethrow;
    }
  }

  Future<void> removeFromTrainingCircle(String currentUserId, String targetUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .doc(targetUserId)
        .delete();
  }

  Future<bool> isMutualFollow(String userIdA, String userIdB) async {
    final isAFollowsB = await isFollowing(userIdA, userIdB);
    final isBFollowsA = await isFollowing(userIdB, userIdA);
    return isAFollowsB && isBFollowsA;
  }

  Future<bool> isInTrainingCircle(String userIdA, String userIdB) async {
    final doc = await _firestore
        .collection('users')
        .doc(userIdA)
        .collection('training_circle')
        .doc(userIdB)
        .get();
    return doc.exists;
  }

  Future<bool> isMutualTrainingCircle(String userIdA, String userIdB) async {
    final aHasB = await isInTrainingCircle(userIdA, userIdB);
    final bHasA = await isInTrainingCircle(userIdB, userIdA);
    return aHasB && bHasA;
  }


}
