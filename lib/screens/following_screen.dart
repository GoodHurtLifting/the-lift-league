import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_screen.dart';
import '../services/user_follow_service.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchFollowing() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      Map<String, dynamic>? userData;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();
        userData = userDoc.data();
      } catch (_) {
        userData = null;
      }

      final data = doc.data();
      result.add({
        'userId': doc.id,
        'displayName': userData?['displayName'] ?? data['displayName'] ?? 'Unknown',
        'profileImageUrl':
            userData?['profileImageUrl'] ?? data['profileImageUrl'] ?? '',
        'title': userData?['title'] ?? data['title'] ?? '',
      });
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFollowing(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'You are not following anyone.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _FollowingTile(user: user);
            },
          );
        },
      ),
    );
  }
}

class _FollowingTile extends StatefulWidget {
  final Map<String, dynamic> user;

  const _FollowingTile({required this.user});

  @override
  State<_FollowingTile> createState() => _FollowingTileState();
}

class _FollowingTileState extends State<_FollowingTile> {
  late bool isFollowing;

  @override
  void initState() {
    super.initState();
    isFollowing = true;
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
          if (isFollowing) {
            await UserFollowService().unfollowUser(currentUserId, user['userId']);
          } else {
            await UserFollowService().followUser(currentUserId, user['userId']);
          }
          setState(() => isFollowing = !isFollowing);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.red : Colors.blue,
        ),
        child: Text(isFollowing ? 'Unfollow' : 'Follow'),
      ),
    );
  }
}
