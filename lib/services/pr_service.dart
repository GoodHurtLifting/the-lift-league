import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> updateBig3PR({
  required String userId,
  required String liftName,
  required double weightUsed,
}) async {
  if (!(liftName == 'Bench Press' || liftName == 'Squats' || liftName == 'Deadlift')) return;

  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('big3_prs')
      .doc(liftName);

  final existing = await docRef.get();
  final currentBest = existing.data()?['bestWeight'] ?? 0;

  if (weightUsed > currentBest) {
    await docRef.set({'bestWeight': weightUsed});
  }
}
