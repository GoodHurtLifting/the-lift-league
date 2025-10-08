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
  // 👩‍🍳 Lunch Lady Badge – new personal best on a big 3 lift
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardLunchLadyBadge({
    required String userId,
    required String liftName,
    required double weight,
  }) async {
    // Only award for meaningful weights
    if (weight <= 0) return [];

    final badgeRef =
        _firestore.collection('users').doc(userId).collection('badges');
    final badgeId =
        'lunch_lady_${liftName.toLowerCase().replaceAll(' ', '_')}_${weight.floor()}';

    final badgeDoc = await badgeRef.doc(badgeId).get();
    if (badgeDoc.exists) return [];

    final badgeData = {
      'badgeId': badgeId,
      'name': 'Lunch Lady',
      'description': '$liftName PR - ${weight.toStringAsFixed(0)} lbs!',
      'image': 'lunchLady_01.png',
    };

    await badgeRef.doc(badgeId).set({
      ...badgeData,
      'iconPath': 'assets/images/badges/lunchLadyIcon_01.png',
      'imagePath': 'assets/images/badges/lunchLady_01.png',
      'unlockDate': Timestamp.now(),
    });

    return [badgeData];
  }

  // ─────────────────────────────────────────────────────────────────────
  // 🕳️ Punch Card Badge – 4 consecutive weeks with ≥3 workouts
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardPunchCardBadge(String userId) async {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));

    final workoutsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .where('completed', isEqualTo: true)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(fourWeeksAgo))
        .get();

    final Map<String, int> weeklyCounts = {};
    for (var doc in workoutsSnap.docs) {
      final ts = (doc['timestamp'] as Timestamp).toDate();
      final isoWeek = isoWeekAndYear(ts);
      weeklyCounts[isoWeek] = (weeklyCounts[isoWeek] ?? 0) + 1;
    }

    final sortedWeeks = weeklyCounts.keys.toList()..sort();
    int streak = 0;
    for (String week in sortedWeeks.reversed) {
      if (weeklyCounts[week]! >= 3) {
        streak++;
        if (streak == 4) break;
      } else {
        break;
      }
    }

    if (streak == 4) {
      // Check for Punch Card badge earned in the past 28 days
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
        if (now.difference(lastUnlock).inDays < 28) {
          return []; // already earned in this 4-week window
        }
      }

      final badgeId = 'punch_card_${now.millisecondsSinceEpoch}';
      final badgeData = {
        'badgeId': badgeId,
        'name': 'Punch Card',
        'description': '4 straight weeks of consistency. Clock in, clock out.',
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
  // 📣 Hype Man Badge – every 10 likes given
  // ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardHypeManBadge(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final likesGiven = (userDoc.data()?['likesGiven'] ?? 0) as int;
    final earnedBadges = likesGiven ~/ 10;

    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');
    List<Map<String, dynamic>> newlyEarned = [];

    for (int i = 1; i <= earnedBadges; i++) {
      final badgeId = 'hype_man_$i';
      final badgeDoc = await badgeRef.doc(badgeId).get();

      if (!badgeDoc.exists) {
        final badgeData = {
          'badgeId': badgeId,
          'name': 'Hype Man',
          'description': 'You liked ${i * 10} check-ins.',
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

    if (topCount < 9 || topUser.isEmpty) {
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
// ✅ Check-In Head – every 5 check-ins
// ─────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checkAndAwardCheckinHeadBadge(
      String userId, {
        int? totalCheckinsOverride, // if you maintain a counter on user doc
      }) async {
    // 1) Determine total check-ins
    int totalCheckins;
    if (totalCheckinsOverride != null) {
      totalCheckins = totalCheckinsOverride;
    } else {
      // Aggregate count on timeline_entries where type == 'checkin'
      final agg = await _firestore
          .collection('users')
          .doc(userId)
          .collection('timeline_entries')
          .where('type', isEqualTo: 'checkin')
          .count()
          .get();
      totalCheckins = agg.count ?? 0;
    }

    // 2) One badge each time total is a multiple of 5
    final earnedBadges = totalCheckins ~/ 5;
    if (earnedBadges <= 0) return [];

    final badgeRef = _firestore.collection('users').doc(userId).collection('badges');
    List<Map<String, dynamic>> newlyEarned = [];

    for (int i = 1; i <= earnedBadges; i++) {
      final badgeId = 'checkin_head_$i';
      final exists = await badgeRef.doc(badgeId).get();
      if (exists.exists) continue;

      final countSoFar = i * 5;
      final badgeData = {
        'badgeId': badgeId,
        'name': 'Checkin Head',
        'description': 'Posted $countSoFar check-ins.',
        'image': 'checkinHead_01.png',
      };

      await badgeRef.doc(badgeId).set({
        ...badgeData,
        'iconPath': 'assets/images/badges/checkinHead_01.png',
        'imagePath': 'assets/images/badges/checkinHead_01.png',
        'unlockDate': Timestamp.now(),
      });

      newlyEarned.add(badgeData);
    }

    return newlyEarned;
  }


  // ─────────────────────────────────────────────────────────────────────
  // 🔢 Helper – Get ISO Week Key
  // ─────────────────────────────────────────────────────────────────────
  String isoWeekAndYear(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final isoYear = thursday.year;
    final firstThursday = DateTime(isoYear, 1, 4);
    final week1 = firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
    final isoWeek = ((thursday.difference(week1).inDays) ~/ 7) + 1;
    return '$isoYear-${isoWeek.toString().padLeft(2, '0')}';
  }


}
