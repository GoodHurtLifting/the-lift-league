import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/services/user_stats_service.dart';
import 'package:intl/intl.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────
  // 🥩 Meat Wagon Badge – every 100,000 lbs lifted
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardMeatWagonBadge(String userId) async {
    final totalLbs = await UserStatsService().getTotalLbsLifted(userId);
    final earnedBadges = (totalLbs ~/ 100000);

    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');
    List<Map<String, dynamic>> newlyEarned = [];

    for (int i = 1; i <= earnedBadges; i++) {
      final badgeId = 'meat_wagon_$i';
      final badgeDoc = await badgeRef.doc(badgeId).get();

      if (!badgeDoc.exists) {
        final badgeData = {
          'badgeId': badgeId,
          'name': 'Meat Wagon',
          'description': 'You’ve moved ${i * 100000} lbs of iron.',
          'image': 'meatWagon_01.png', // match your BadgeCarousel load path
        };
        await badgeRef.doc(badgeId).set({
          ...badgeData,
          'iconPath': 'assets/images/badges/meatWagonIcon_01.png',
          'imagePath': 'assets/images/badges/meatWagon_01.png',
          'unlockDate': Timestamp.now(),
        });
        newlyEarned.add(badgeData);
      }
    }

    return newlyEarned;
  }


  // ─────────────────────────────────────────────────────────────────────
  // 👩‍🍳 Lunch Lady Badge – lift PR milestones (135/225/315/405)
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardLunchLadyBadge({
    required String userId,
    required String liftName,
    required double weight,
  }) async {
    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');
    List<Map<String, dynamic>> newlyEarned = [];

    final List<Map<String, dynamic>> liftMilestones = [
      {'lift': 'Bench Press', 'thresholds': [135, 225, 315]},
      {'lift': 'Squats', 'thresholds': [225, 315, 405]},
      {'lift': 'Deadlift', 'thresholds': [225, 315, 405]},
    ];

    for (final lift in liftMilestones) {
      if (liftName != lift['lift']) continue;

      for (final int milestone in lift['thresholds']) {
        if (weight >= milestone) {
          final badgeId = 'lunch_lady_${liftName.toLowerCase().replaceAll(' ', '_')}_$milestone';
          final badgeDoc = await badgeRef.doc(badgeId).get();

          if (!badgeDoc.exists) {
            final badgeData = {
              'badgeId': badgeId,
              'name': 'Lunch Lady',
              'description': '$liftName for $milestone lbs — that’s a stack of plates.',
              'image': 'lunchLady_01.png',
            };

            await badgeRef.doc(badgeId).set({
              ...badgeData,
              'iconPath': 'assets/images/badges/lunchLadyIcon_01.png',
              'imagePath': 'assets/images/badges/lunchLady_01.png',
              'unlockDate': Timestamp.now(),
            });

            newlyEarned.add(badgeData);
          }
        }
      }
    }

    return newlyEarned;
  }

  // ─────────────────────────────────────────────────────────────────────
  // 🕳️ Punch Card Badge – 8 consecutive weeks with ≥3 workouts
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardPunchCardBadge(String userId) async {
    final now = DateTime.now();
    final eightWeeksAgo = now.subtract(const Duration(days: 56));

    final workoutsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .where('completed', isEqualTo: true)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(eightWeeksAgo))
        .get();

    final Map<String, int> weeklyCounts = {};
    for (var doc in workoutsSnap.docs) {
      final ts = (doc['timestamp'] as Timestamp).toDate();
      final isoWeek = getIsoWeekKey(ts);
      weeklyCounts[isoWeek] = (weeklyCounts[isoWeek] ?? 0) + 1;
    }

    final sortedWeeks = weeklyCounts.keys.toList()..sort();
    int streak = 0;
    for (String week in sortedWeeks.reversed) {
      if (weeklyCounts[week]! >= 3) {
        streak++;
        if (streak == 8) break;
      } else {
        break;
      }
    }

    if (streak == 8) {
      // Check for Punch Card badge earned in the past 56 days
      final recentBadgesSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .where('name', isEqualTo: 'Punch Card')
          .orderBy('unlockDate', descending: true)
          .limit(1)
          .get();

      if (recentBadgesSnap.docs.isNotEmpty) {
        final lastUnlock = (recentBadgesSnap.docs.first['unlockDate'] as Timestamp).toDate();
        if (now.difference(lastUnlock).inDays < 56) {
          return []; // already earned in this 8-week window
        }
      }

      final badgeId = 'punch_card_${now.millisecondsSinceEpoch}';
      final badgeData = {
        'badgeId': badgeId,
        'name': 'Punch Card',
        'description': '8 straight weeks of consistency. Clock in, clock out.',
        'image': 'punchCard_01.png',
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .set({
        ...badgeData,
        'iconPath': 'assets/images/badges/punchCardIcon_01.png',
        'imagePath': 'assets/images/badges/punchCard_01.png',
        'unlockDate': Timestamp.now(),
      });

      return [badgeData];
    }

    return [];
  }


  // ─────────────────────────────────────────────────────────────────────
  // 📣 Hype Man Badge – every 100 likes given
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardHypeManBadge(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final likesGiven = (userDoc.data()?['likesGiven'] ?? 0) as int;
    final earnedBadges = likesGiven ~/ 100;

    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');
    List<Map<String, dynamic>> newlyEarned = [];

    for (int i = 1; i <= earnedBadges; i++) {
      final badgeId = 'hype_man_$i';
      final badgeDoc = await badgeRef.doc(badgeId).get();

      if (!badgeDoc.exists) {
        final badgeData = {
          'badgeId': badgeId,
          'name': 'Hype Man',
          'description': 'You liked ${i * 100} check-ins.',
          'image': 'hypeMan.png',
        };

        await badgeRef.doc(badgeId).set({
          ...badgeData,
          'iconPath': 'assets/images/badges/hypeMan.png',
          'imagePath': 'assets/images/badges/hypeMan.png',
          'unlockDate': Timestamp.now(),
        });

        newlyEarned.add(badgeData);
      }
    }

    return newlyEarned;
  }

  // ─────────────────────────────────────────────────────────────────────
  // 🚗 Daily Driver Badge – most workouts in training circle per month
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardDailyDriverBadge(String userId) async {
    // Fetch training circle members
    final circleSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('training_circle')
        .get();

    if (circleSnap.docs.isEmpty) {
      return [];
    }

    final memberIds = circleSnap.docs.map((d) => d.id).toList();
    memberIds.add(userId); // include self

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final prevMonthEnd = currentMonthStart.subtract(const Duration(days: 1));
    final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);

    final startTs = Timestamp.fromDate(prevMonthStart);
    final endTs = Timestamp.fromDate(currentMonthStart);

    String topUser = '';
    int topCount = 0;

    for (final id in memberIds) {
      final snap = await _firestore
          .collection('users')
          .doc(id)
          .collection('workouts')
          .where('completed', isEqualTo: true)
          .where('timestamp', isGreaterThanOrEqualTo: startTs)
          .where('timestamp', isLessThan: endTs)
          .get();

      final count = snap.docs.length;
      if (count > topCount) {
        topCount = count;
        topUser = id;
      }
    }

    if (topCount < 12 || topUser.isEmpty) {
      return [];
    }

    final badgeId =
        'daily_driver_${prevMonthStart.year}_${prevMonthStart.month.toString().padLeft(2, '0')}';

    final badgeRef = _firestore
        .collection('users')
        .doc(topUser)
        .collection('badges')
        .doc(badgeId);

    final badgeDoc = await badgeRef.get();
    if (badgeDoc.exists) {
      return [];
    }

    final monthName = DateFormat('MMMM yyyy').format(prevMonthStart);

    final badgeData = {
      'badgeId': badgeId,
      'name': 'Daily Driver',
      'description': 'Most workouts logged in $monthName.',
      'image': 'dailyDriver.png',
    };

    await badgeRef.set({
      ...badgeData,
      'iconPath': 'assets/images/badges/dailyDriver.png',
      'imagePath': 'assets/images/badges/dailyDriver.png',
      'unlockDate': Timestamp.now(),
    });

    return topUser == userId ? [badgeData] : [];
  }

  // ─────────────────────────────────────────────────────────────────────
  // 🔢 Helper – Get ISO Week Key
  // ─────────────────────────────────────────────────────────────────────
  String getIsoWeekKey(DateTime date) {
    final weekYear = DateFormat('yyyy').format(date);
    final weekOfYear = ((date.difference(DateTime(date.year, 1, 1)).inDays +
        DateTime(date.year, 1, 1).weekday - 1) ~/
        7) +
        1;
    return '$weekYear-W$weekOfYear';
  }

}
