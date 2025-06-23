import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_screen.dart';
import '../services/user_follow_service.dart';

class TrainingCircleMembersScreen extends StatelessWidget {
  const TrainingCircleMembersScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchMembers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'userId': doc.id,
        'displayName': data['displayName'] ?? 'Unknown',
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'title': data['title'] ?? '',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Circle'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMembers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Your training circle is empty.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _CircleMemberTile(user: user);
            },
          );
        },
      ),
    );
  }
}

class _CircleMemberTile extends StatefulWidget {
  final Map<String, dynamic> user;

  const _CircleMemberTile({required this.user});

  @override
  State<_CircleMemberTile> createState() => _CircleMemberTileState();
}

class _CircleMemberTileState extends State<_CircleMemberTile> {
  late bool inCircle;

  @override
  void initState() {
    super.initState();
    inCircle = true;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final profileUrl = user['profileImageUrl'];

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: user['userId']),
          ),
        );
      },
      leading: CircleAvatar(
        backgroundImage: profileUrl != null &&
                profileUrl.toString().startsWith('http')
            ? NetworkImage(profileUrl)
            : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
      ),
      title: Text(
        user['displayName'] ?? 'Unknown',
        style: const TextStyle(
            color: Color(0xFFFC3B3D), fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        user['title'] ?? '',
        style: const TextStyle(
          color: Colors.white70,
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      ),
      trailing: ElevatedButton(
        onPressed: () async {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == null) return;
          if (inCircle) {
            await UserFollowService()
                .removeFromTrainingCircle(currentUserId, user['userId']);
          } else {
            await UserFollowService().addToTrainingCircle(currentUserId, {
              'userId': user['userId'],
              'displayName': user['displayName'],
              'profileImageUrl': user['profileImageUrl'],
              'title': user['title'],
            });
          }
          setState(() => inCircle = !inCircle);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: inCircle ? Colors.red : Colors.blue,
        ),
        child: Text(inCircle ? 'Remove' : 'Add'),
      ),
    );
  }
}
