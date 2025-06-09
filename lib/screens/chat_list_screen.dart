import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:lift_league/services/chat_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lift_league/services/notifications_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenForCircleNotifications();
  }

  void _listenForCircleNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'training_circle_add')
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final fromName = data['fromDisplayName'] ?? 'Someone';
          NotificationService().showSimpleNotification(
            'Training Circle',
            '$fromName added you to their training circle',
          );
          change.doc.reference.update({'seen': true});
        }
      }
    });
  }

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

  Future<List<Map<String, dynamic>>> _fetchActivity(String currentUserId) async {
    final firestore = FirebaseFirestore.instance;
    final followersSnap = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('followers')
        .orderBy('timestamp', descending: true)
        .get();

    final circleSnap = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'training_circle_add')
        .orderBy('timestamp', descending: true)
        .get();

    final items = <Map<String, dynamic>>[];

    for (final doc in followersSnap.docs) {
      final userDoc = await firestore.collection('users').doc(doc.id).get();
      final data = userDoc.data() ?? {};
      items.add({
        'type': 'follow',
        'userId': doc.id,
        'displayName': data['displayName'] ?? 'Unknown',
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'timestamp': doc['timestamp'] as Timestamp?,
      });
    }

    for (final doc in circleSnap.docs) {
      final fromId = doc['fromUserId'];
      final userDoc = await firestore.collection('users').doc(fromId).get();
      final data = userDoc.data() ?? {};
      items.add({
        'type': 'circle',
        'userId': fromId,
        'displayName': data['displayName'] ?? doc['fromDisplayName'] ?? 'Unknown',
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'timestamp': doc['timestamp'] as Timestamp?,
      });
    }

    items.sort((a, b) {
      final at = a['timestamp'] as Timestamp?;
      final bt = b['timestamp'] as Timestamp?;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return items;
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

  Widget _buildChats(String currentUserId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTrainingCircleUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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
                      backgroundImage: (profileUrl != null &&
                              profileUrl.toString().startsWith('http'))
                          ? NetworkImage(profileUrl)
                          : const AssetImage('assets/images/flatLogo.jpg')
                              as ImageProvider,
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
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  onTap: () async {
                    final chatId =
                        await getOrCreateChat(currentUserId, otherUserId);

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
    );
  }

  Widget _buildActivity(String currentUserId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchActivity(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;

        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No recent activity.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final profileUrl = item['profileImageUrl'];
            final ts = item['timestamp'] as Timestamp?;
            final time = ts != null ? timeago.format(ts.toDate()) : '';
            final text = item['type'] == 'circle'
                ? '${item['displayName']} added you to their training circle'
                : '${item['displayName']} followed you';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (profileUrl != null &&
                        profileUrl.toString().startsWith('http'))
                    ? NetworkImage(profileUrl)
                    : const AssetImage('assets/images/flatLogo.jpg')
                        as ImageProvider,
              ),
              title: Text(
                text,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                time,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Circle'),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      backgroundColor: Colors.black,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChats(currentUserId),
          _buildActivity(currentUserId),
        ],
      ),
    );
  }
}
