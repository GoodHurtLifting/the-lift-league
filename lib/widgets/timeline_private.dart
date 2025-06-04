import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/models/timeline_entry.dart';
import 'package:lift_league/modals/clink_composer.dart';
import 'package:lift_league/widgets/dismissible_timeline_item.dart';


class TimelinePrivate extends StatefulWidget {
  final String userId;
  final void Function()? onCheckInUploaded;
  const TimelinePrivate({super.key, required this.userId, this.onCheckInUploaded});

  @override
  State<TimelinePrivate> createState() => _TimelinePrivateState();
}

class _TimelinePrivateState extends State<TimelinePrivate> {
  bool showBeforeAfter = false;
  bool _showSeeYouMessage = false;
  bool _hasUploadedThisSession = false;



  Future<DateTime?> _getLastCheckIn() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .where('type', isEqualTo: 'checkin') // ✅ filter check-ins only
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();


    if (snapshot.docs.isEmpty) return null;
    final lastEntry = snapshot.docs.first.data();
    final ts = lastEntry['timestamp'];
    return ts is Timestamp ? ts.toDate() : DateTime.tryParse(ts.toString());
  }

  Widget _buildBeforeAfter(TimelineEntry before, TimelineEntry after) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text("Before", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Image.network(before.imageUrls[i], height: 250, fit: BoxFit.cover),
                      if (i == 0 && before.weight != null) Text("Weight: ${before.weight} lbs"),
                      if (i == 0 && before.bodyFat != null) Text("Body Fat: ${before.bodyFat}%"),
                      if (i == 0 && before.bmi != null) Text("BMI: ${before.bmi}"),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text("After", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Image.network(after.imageUrls[i], height: 250, fit: BoxFit.cover),
                      if (i == 0 && after.weight != null) Text("Weight: ${after.weight} lbs"),
                      if (i == 0 && after.bodyFat != null) Text("Body Fat: ${after.bodyFat}%"),
                      if (i == 0 && after.bmi != null) Text("BMI: ${after.bmi}"),
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
    return FutureBuilder<DateTime?>(
      future: _getLastCheckIn(),
      builder: (context, checkInSnapshot) {
        final now = DateTime.now();
        final lastCheckIn = checkInSnapshot.data;
        final canUpload = lastCheckIn == null || now.difference(lastCheckIn).inDays >= 14;

        return StreamBuilder<List<TimelineEntry>>(
          stream: _timelineStream(widget.userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data!;
            final checkIns = entries.where((e) => e.type == 'checkin').toList();
            final hasEnoughForBA = checkIns.length >= 3;
            final visibleEntries = showBeforeAfter ? checkIns : entries;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text("Timeline", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),

                if (_showSeeYouMessage)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        '✅ See you in 2 weeks!',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Add Check-In Button
                      ElevatedButton(
                        onPressed: (canUpload && !_hasUploadedThisSession)
                            ? () async {
                          final result = await Navigator.pushNamed(context, '/addCheckIn');
                          if (result == true) {
                            setState(() {
                              _hasUploadedThisSession = true;
                              _showSeeYouMessage = true;
                            });
                            widget.onCheckInUploaded?.call();
                          }
                        }
                            : null,
                        child: const Text("Check-In"),
                      ),

                      // Drop Clink Button
                      ElevatedButton(
                        onPressed: () async {
                          final result = await showGeneralDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: 'Clink Composer',
                            barrierColor: Colors.black.withOpacity(0.8),
                            transitionDuration: const Duration(milliseconds: 300),
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                                  ),
                                  child: const ClinkComposer(),
                                ),
                              );
                            },
                            transitionBuilder: (context, animation, secondaryAnimation, child) {
                              final offsetAnimation = Tween<Offset>(
                                begin: const Offset(0, -1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

                              return SlideTransition(position: offsetAnimation, child: child);
                            },
                          );

                          if (result == true) {
                            setState(() {}); // 🔁 refresh timeline
                          }
                        },
                        child: const Text("Clink"),
                      ),

                      // Toggle B&A Button
                      if (hasEnoughForBA)
                        TextButton(
                          onPressed: () {
                            setState(() => showBeforeAfter = !showBeforeAfter);
                          },
                          child: Text(
                            showBeforeAfter ? "Timeline" : "B&A",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text("Load ‘Before’ photos."),
                  )
                else if (showBeforeAfter && hasEnoughForBA)
                  _buildBeforeAfter(checkIns.last, checkIns.first)
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      return DismissibleTimelineItem(
                        userId: widget.userId,
                        entry: entry,
                        refresh: () => setState(() {}),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
