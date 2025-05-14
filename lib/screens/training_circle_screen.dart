import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/timeline_clink_card.dart';
import 'package:lift_league/widgets/timeline_checkin_card.dart';
import 'package:lift_league/models/timeline_entry.dart';

class TrainingCircleScreen extends StatelessWidget {
  const TrainingCircleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Circle'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<String>>(
        future: _fetchCircleMemberIds(currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final memberIds = snapshot.data!;
          if (memberIds.isEmpty) {
            return const Center(
              child: Text(
                'Your circle is empty.\nStart adding lifters!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('timeline_entries')
                .where('userId', whereIn: memberIds)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final entries = snapshot.data!.docs;

              if (entries.isEmpty) {
                return const Center(
                  child: Text('No timeline activity yet.', style: TextStyle(color: Colors.white70)),
                );
              }

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final doc = entries[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'checkin';
                  final entry = TimelineEntry.fromMap(doc.id, data);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: entry.type == 'clink'
                        ? TimelineClinkCard(
                      clink: entry.clink ?? '',
                      timestamp: entry.timestamp,
                      displayName: entry.displayName,
                      title: entry.title,
                      profileImageUrl: entry.profileImageUrl,
                      showProfileInfo: true,
                      onTapProfile: () {
                        Navigator.pushNamed(
                          context,
                          '/publicProfile',
                          arguments: {'userId': entry.userId},
                        );
                      },
                    )
                        : TimelineCheckinCard(
                      entry: entry,
                      entryId: doc.id,
                      userId: entry.userId,
                      displayName: entry.displayName,
                      title: entry.title,
                      profileImageUrl: entry.profileImageUrl,
                      showProfileInfo: true,
                      showCheckInInfo: true,
                      onTapProfile: () {
                        Navigator.pushNamed(
                          context,
                          '/publicProfile',
                          arguments: {'userId': entry.userId},
                        );
                      },
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

  Future<List<String>> _fetchCircleMemberIds(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('training_circle')
        .get();

    final memberIds = snapshot.docs.map((doc) => doc.id).toList();
    memberIds.add(userId); // Add yourself to the list

    // Remove any accidental duplicates by converting to a Set, then back to List
    return memberIds.toSet().toList();
  }
}
