import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/screens/public_profile_screen.dart';
import 'package:lift_league/services/user_follow_service.dart';

class UserSearchTile extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> user;

  const UserSearchTile({
    super.key,
    required this.userId,
    required this.user,
  });

  @override
  State<UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends State<UserSearchTile> {
  bool isFollowing = false;
  bool isInCircle = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final result = await UserFollowService().isFollowing(currentUserId, widget.userId);
    final circleDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .doc(widget.userId)
        .get();

    setState(() {
      isFollowing = result;
      isInCircle = circleDoc.exists;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: widget.userId),
          ),
        );
      },
      leading: CircleAvatar(
        backgroundImage: user['profileImageUrl'] != null &&
            user['profileImageUrl'].toString().startsWith('http')
            ? NetworkImage(user['profileImageUrl'])
            : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
      ),
      title: Text(
        user['displayName'] ?? 'Unknown',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        user['title'] ?? '',
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: loading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : isFollowing
          ? isInCircle
          ? IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green),
        onPressed: () async {
          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
          await UserFollowService().removeFromTrainingCircle(currentUserId, widget.userId);
          setState(() => isInCircle = false);
        },
      )
          : ElevatedButton(
        onPressed: () async {
          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
          await UserFollowService().addToTrainingCircle(currentUserId, {
            'userId': widget.userId,
            'displayName': user['displayName'],
            'profileImageUrl': user['profileImageUrl'],
            'title': user['title'],
          });
          setState(() => isInCircle = true);
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        child: const Text('Add to Circle'),
      )
          : ElevatedButton(
        onPressed: () async {
          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
          await UserFollowService().followUser(currentUserId, widget.userId);
          setState(() => isFollowing = true);
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Follow'),
      ),
    );
  }
}
