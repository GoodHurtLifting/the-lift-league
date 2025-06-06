import 'package:lift_league/widgets/leaderboard_tile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
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
                child: Text('🏆 Top Performers', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
