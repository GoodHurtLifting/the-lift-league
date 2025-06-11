import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/leaderboard_tile.dart';
import 'package:lift_league/widgets/badge_board_tile.dart';

class LeaderboardScreen extends StatelessWidget {
  final int blockId;

  const LeaderboardScreen({super.key, required this.blockId});

  Stream<List<Map<String, dynamic>>> leaderboardStream() {
    return FirebaseFirestore.instance
        .collection('leaderboards')
        .doc(blockId.toString())
        .collection('entries')
        .orderBy('blockScore', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'userId': doc.id,
        'displayName': data['displayName'] ?? 'Unknown',
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'title': data['title'] ?? '',
        'blockScore':
        (double.tryParse(data['blockScore'].toString()) ?? 0.0)
            .toStringAsFixed(1),
        'workoutScores':
        (data['workoutScores'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      };
    }).toList());
  }

  Future<List<Map<String, dynamic>>> badgeBoard() async {
    final firestore = FirebaseFirestore.instance;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];

    final circleSnap = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .get();

    final memberIds = circleSnap.docs.map((d) => d.id).toList();
    memberIds.add(currentUserId);

    final ids = memberIds.toSet().toList();

    final futures = ids.map((id) async {
      final userDoc = await firestore.collection('users').doc(id).get();
      final userData = userDoc.data() ?? {};
      final badgesSnap = await firestore
          .collection('users')
          .doc(id)
          .collection('badges')
          .get();

      return {
        'userId': id,
        'displayName': userData['displayName'] ?? 'Unknown',
        'profileImageUrl': userData['profileImageUrl'] ?? '',
        'title': userData['title'] ?? '',
        'badgeCount': badgesSnap.docs.length,
      };
    });

    final entries = await Future.wait(futures);
    entries.sort((a, b) =>
        (b['badgeCount'] as int).compareTo(a['badgeCount'] as int));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Block'),
              Tab(text: 'Badges'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBlockLeaderboard(),
            _buildBadgeBoard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockLeaderboard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: leaderboardStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading leaderboard: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No scores yet. Be the first to log a workout!',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final data = snapshot.data!;

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('🏆 Top Performers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final entry = data[index];
                  return LeaderboardTile(
                    userId: entry['userId'],
                    displayName: entry['displayName'],
                    profileImageUrl: entry['profileImageUrl'],
                    blockScore: entry['blockScore'],
                    workoutScores: List<String>.from(entry['workoutScores']),
                    title: entry['title'],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgeBoard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: badgeBoard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(child: Text('No badges earned yet.'));
        }

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final entry = data[index];
            return BadgeBoardTile(
              userId: entry['userId'],
              displayName: entry['displayName'],
              profileImageUrl: entry['profileImageUrl'],
              title: entry['title'],
              badgeCount: entry['badgeCount'] as int,
            );
          },
        );
      },
    );
  }
}
