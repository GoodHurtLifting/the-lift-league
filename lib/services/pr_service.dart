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

Future<Map<String, double>> getBig3PRs(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('big3_prs')
      .get();

  final prs = <String, double>{};
  for (var doc in snapshot.docs) {
    final liftName = doc.id;
    final weight = (doc.data()['bestWeight'] ?? 0).toDouble();
    prs[liftName] = weight;
  }

  return prs;
}
