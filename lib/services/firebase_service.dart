import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      await _createUserProfileIfNeeded(result.user);
      return result.user;
    } catch (e) {
      print('❌ Auth error: $e');
      return null;
    }
  }

  // Check if profile exists in Firestore, create if not
  Future<void> _createUserProfileIfNeeded(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'displayName': 'New Lifter',
        'title': 'Lone Wolf',
        'blocksCompleted': 0,
        'totalLbsLifted': 0, // ✅ Add this
        'profileImageUrl': '', // ✅ Already there
      });
    }
  }

  User? get currentUser => _auth.currentUser;
}
