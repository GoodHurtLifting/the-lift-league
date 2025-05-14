import 'package:cloud_firestore/cloud_firestore.dart';

class UserFollowService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final now = Timestamp.now();

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .set({'timestamp': now});

    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .set({'timestamp': now});
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
    final circleRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle');

    final snapshot = await circleRef.get();
    if (snapshot.size >= 10) return; // Limit to 10 members

    await circleRef.doc(userData['userId']).set({
      'displayName': userData['displayName'],
      'profileImageUrl': userData['profileImageUrl'],
      'title': userData['title'],
      'timestamp': Timestamp.now(),
    });
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

}
