import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_screen.dart';

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
              final profileUrl = user['profileImageUrl'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (profileUrl != null &&
                          profileUrl.toString().startsWith('http'))
                      ? NetworkImage(profileUrl)
                      : const AssetImage('assets/images/flatLogo.jpg')
                          as ImageProvider,
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(
                        userId: user['userId'],
                      ),
                    ),
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
