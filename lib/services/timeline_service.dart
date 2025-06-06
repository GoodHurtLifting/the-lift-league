import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineService {
  static Future<void> updateUserInfo({
    required String userId,
    String? displayName,
    String? profileImageUrl,
    String? title,
  }) async {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries');

    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
      if (title != null) updates['title'] = title;
      batch.update(doc.reference, updates);
    }
    await batch.commit();
  }
}