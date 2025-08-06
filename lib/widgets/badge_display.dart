import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:lift_league/services/pr_service.dart';

class BadgeDisplay extends StatelessWidget {
  final String userId;

  const BadgeDisplay({super.key, required this.userId});

  /// Catalog of all available badge types
  List<Map<String, String>> get _badgeCatalog => [
        {
          'name': 'Meat Wagon',
          'icon': 'assets/images/badges/meatWagon_01.png',
          'description': 'Every 100k lbs moved'
        },
        {
          'name': 'Lunch Lady',
          'icon': 'assets/images/badges/lunchLady_01.png',
          'description': 'Hit big PR milestones'
        },
        {
          'name': 'Punch Card',
          'icon': 'assets/images/badges/punchCard_01.png',
          'description': '4 weeks of 3+ workouts'
        },
        {
          'name': 'Hype Man',
          'icon': 'assets/images/badges/hypeMan.png',
          'description': 'Like 50 check-ins'
        },
        {
          'name': 'Daily Driver',
          'icon': 'assets/images/badges/dailyDriver.png',
          'description': 'Most workouts in circle'
        },
      ];

  // Helper to compute ISO week string (yyyy-Wweek)
  String _isoWeekKey(DateTime date) {
    final weekYear = DateFormat('yyyy').format(date);
    final weekOfYear = ((date.difference(DateTime(date.year, 1, 1)).inDays +
                DateTime(date.year, 1, 1).weekday -
                1) ~/
            7) +
        1;
    return '$weekYear-W$weekOfYear';
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final firestore = FirebaseFirestore.instance;

    // Badge counts
    final badgeSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .get();
    final Map<String, int> counts = {};
    for (var doc in badgeSnap.docs) {
      final name = doc['name'] ?? '';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    // Stats used for progress calculations
    final userDoc = await firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    final totalLbs = (userData['totalLbsLifted'] ?? 0).toDouble();
    final likesGiven = (userData['likesGiven'] ?? 0) as int;
    final prs = await getBig3PRs(userId);
    double maxPr = 0;
    for (final w in prs.values) {
      maxPr = max(maxPr, w);
    }

    // Punch card progress (4-week streak, up to 12 workouts)
    final now = DateTime.now();
    final startOfCurrentWeek = now.subtract(Duration(days: now.weekday - 1));
    final fourWeeksStart = startOfCurrentWeek.subtract(const Duration(days: 21));
    final workoutsSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .where('completed', isEqualTo: true)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(fourWeeksStart))
        .get();

    final Map<String, int> weeklyCounts = {};
    for (var doc in workoutsSnap.docs) {
      final ts = (doc['timestamp'] as Timestamp).toDate();
      final isoWeek = _isoWeekKey(ts);
      weeklyCounts[isoWeek] = (weeklyCounts[isoWeek] ?? 0) + 1;
    }

    List<String> weekKeys = [];
    DateTime cursor = fourWeeksStart;
    for (int i = 0; i < 4; i++) {
      weekKeys.add(_isoWeekKey(cursor));
      cursor = cursor.add(const Duration(days: 7));
    }

    int streak = 0;
    for (int i = 0; i < 4; i++) {
      final count = weeklyCounts[weekKeys[i]] ?? 0;
      if (count >= 3) {
        streak++;
      } else {
        break;
      }
    }
    int punchProgress = streak * 3; // Fill by 3 for each week

    // Workouts logged this month (for Daily Driver progress)
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .where('completed', isEqualTo: true)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();
    final monthWorkouts = monthSnap.docs.length;

    return {
      'counts': counts,
      'totalLbs': totalLbs,
      'likesGiven': likesGiven,
      'maxPr': maxPr,
      'punchProgress': punchProgress,
      'monthWorkouts': monthWorkouts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final counts = Map<String, int>.from(data['counts'] as Map);
        final totalLbs = data['totalLbs'] as double;
        final likesGiven = data['likesGiven'] as int;
        final maxPr = data['maxPr'] as double;
        final punchProgress = data['punchProgress'] as int;
        final monthWorkouts = data['monthWorkouts'] as int;

        // Build display list with progress values
        final List<Map<String, dynamic>> badges = [];
        for (final def in _badgeCatalog) {
          final name = def['name']!;
          final count = counts[name] ?? 0;
          double progress = 0.0;
          switch (name) {
            case 'Meat Wagon':
              progress = ((totalLbs % 100000) / 100000).clamp(0.0, 1.0);
              break;
            case 'Lunch Lady':
              progress = (maxPr / 405).clamp(0.0, 1.0);
              break;
            case 'Punch Card':
              progress = (punchProgress / 12).clamp(0.0, 1.0);
              break;
            case 'Hype Man':
              progress = ((likesGiven % 100) / 100).clamp(0.0, 1.0);
              break;
            case 'Daily Driver':
              progress = (monthWorkouts / 12).clamp(0.0, 1.0);
              break;
          }
          badges.add({
            'name': name,
            'description': def['description'],
            'icon': def['icon'],
            'count': count,
            'progress': progress,
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Badges',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];

                final bool earned = badge['count'] > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Opacity(
                          opacity: earned ? 1.0 : 0.5,
                          child: Image.asset(
                            badge['icon'],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.error, size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${badge['name']}  x${badge['count']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badge['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: badge['progress'],
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
