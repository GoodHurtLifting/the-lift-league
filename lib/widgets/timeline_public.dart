import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/models/timeline_entry.dart';
import 'package:lift_league/widgets/timeline_checkin_card.dart';
import 'package:lift_league/widgets/timeline_clink_card.dart';

class TimelinePublic extends StatefulWidget {
  final String userId;
  final bool checkInInfo;
  final bool showBeforeAfter;

  const TimelinePublic(
      {super.key,
      required this.userId,
      required this.checkInInfo,
      required this.showBeforeAfter});

  @override
  State<TimelinePublic> createState() => _TimelinePublicState();
}

class _TimelinePublicState extends State<TimelinePublic> {
  Widget _buildBeforeAfter(TimelineEntry before, TimelineEntry after) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Before',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Image.network(before.imageUrls[i],
                          height: 250, fit: BoxFit.cover),
                      if (i == 0 && before.weight != null)
                        Text('Weight: ${before.weight} lbs'),
                      if (i == 0 && before.bodyFat != null)
                        Text('Body Fat: ${before.bodyFat}%'),
                      if (i == 0 && before.bmi != null)
                        Text('BMI: ${before.bmi}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text('After',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Image.network(after.imageUrls[i],
                          height: 250, fit: BoxFit.cover),
                      if (i == 0 && after.weight != null)
                        Text('Weight: ${after.weight} lbs'),
                      if (i == 0 && after.bodyFat != null)
                        Text('Body Fat: ${after.bodyFat}%'),
                      if (i == 0 && after.bmi != null)
                        Text('BMI: ${after.bmi}'),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

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
      stream: _timelineStream(widget.userId),
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

        final checkIns = entries
            .where((e) => e.type == 'checkin' && e.imageUrls.isNotEmpty)
            .toList();
        final hasEnoughForBA = checkIns.length >= 3;

        if (widget.showBeforeAfter && hasEnoughForBA) {
          return _buildBeforeAfter(checkIns.last, checkIns.first);
        }

        return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: .8, vertical: 6.0),
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
                        showCheckInInfo: widget.checkInInfo,
                      ),
              );
            });
      },
    );
  }
}
