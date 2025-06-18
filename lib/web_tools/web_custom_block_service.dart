import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebCustomBlockService {
  Future<List<Map<String, dynamic>>> getCustomBlocks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = int.tryParse(d.id) ?? 0;
      return data;
    }).toList();
  }
}