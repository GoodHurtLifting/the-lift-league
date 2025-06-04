import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/models/timeline_entry.dart';
import 'package:lift_league/widgets/timeline_checkin_card.dart';
import 'package:lift_league/widgets/timeline_clink_card.dart';

class TimelinePublic extends StatelessWidget {
  final String userId;
  final bool checkInInfo;

  const TimelinePublic({super.key, required this.userId, required this.checkInInfo});

  Stream<List<TimelineEntry>> _timelineStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => TimelineEntry.fromMap(doc.id, doc.data()))
        .toList());
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimelineEntry>>(
      stream: _timelineStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No public timeline activity yet."),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: .8),
              child: entry.type == 'clink'
                  ? TimelineClinkCard(
                clink: entry.clink ?? '',
                timestamp: entry.timestamp,
                displayName: entry.displayName,
                title: entry.title,
                profileImageUrl: entry.profileImageUrl,
                imageUrls: entry.imageUrls,
                showProfileInfo: false,
              )
                  : TimelineCheckinCard(
                entry: entry,
                entryId: entry.entryId,
                userId: entry.userId,
                readonly: true,
                showCheckInInfo: checkInInfo,
              ),
            );
          }
        );
      },
    );
  }
}
