import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> getOrCreateChat(String userId1, String userId2) async {
  final chatId = userId1.hashCode <= userId2.hashCode
      ? '${userId1}_$userId2'
      : '${userId2}_$userId1';

  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  final doc = await chatRef.get();

  if (!doc.exists) {
    await chatRef.set({
      'chatId': chatId,
      'members': [userId1, userId2],
      'lastMessage': '',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'blockedBy': null,
    });
  }

  return chatId;
}
