import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:lift_league/services/chat_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchTrainingCircleUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final circleSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .get();

    if (circleSnapshot.docs.isEmpty) return [];

    final users = <Map<String, dynamic>>[];

    for (final doc in circleSnapshot.docs) {
      final data = doc.data();
      final otherUserId = doc.id;
      final chatId = currentUserId.hashCode <= otherUserId.hashCode
          ? '${currentUserId}_$otherUserId'
          : '${otherUserId}_$currentUserId';

      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      final lastTimestamp = chatDoc.data()?['lastTimestamp'] as Timestamp?;

      users.add({
        'userId': otherUserId,
        'displayName': data['displayName'] ?? 'Unknown',
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'title': data['title'] ?? '',
        'lastTimestamp': lastTimestamp,
      });
    }

    // Sort by most recent message time (nulls go last)
    users.sort((a, b) {
      final aTime = a['lastTimestamp'] as Timestamp?;
      final bTime = b['lastTimestamp'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return users;
  }



  Future<Map<String, dynamic>> _getChatPreview(String chatId, String currentUserId) async {
    final messageQuery = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    final latestMsg = messageQuery.docs.isEmpty ? null : messageQuery.docs.first;
    final data = latestMsg?.data();

    return {
      'message': data?['text'] ?? '',
      'timestamp': data?['timestamp'],
      'unread': !(data?['seenBy']?.contains(currentUserId) ?? true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Circle Chats'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchTrainingCircleUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!;

          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Your Training Circle is empty.\nAdd teammates to start chatting!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final profileUrl = user['profileImageUrl'];
              final otherUserId = user['userId'];
              final chatId = currentUserId.hashCode <= otherUserId.hashCode
                  ? '${currentUserId}_$otherUserId'
                  : '${otherUserId}_$currentUserId';

              return FutureBuilder<Map<String, dynamic>>(
                future: _getChatPreview(chatId, currentUserId),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {};
                  final lastMessage = data['message'] ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final isUnread = data['unread'] ?? false;
                  final formattedTime = timestamp != null
                      ? timeago.format(timestamp.toDate())
                      : '';

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundImage: (profileUrl != null && profileUrl.toString().startsWith('http'))
                            ? NetworkImage(profileUrl)
                            : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
                      ),
                    ),
                    title: Text(
                      user['displayName'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Color(0xFFFC3B3D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                        if (lastMessage.isNotEmpty)
                          Text(
                            '$lastMessage • $formattedTime',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    onTap: () async {
                      final chatId = await getOrCreateChat(currentUserId, otherUserId);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: chatId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
