import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/screens/user_dashboard.dart';
import 'package:lift_league/services/user_stats_service.dart';
import 'package:lift_league/widgets/badge_grid.dart';
import 'package:lift_league/services/promo_popup_service.dart';

class BlockSummaryScreen extends StatefulWidget {
  final int blockInstanceId;

  const BlockSummaryScreen({super.key, required this.blockInstanceId});

  @override
  State<BlockSummaryScreen> createState() => _BlockSummaryScreenState();
}

class _BlockSummaryScreenState extends State<BlockSummaryScreen> {
  final UserStatsService _statsService = UserStatsService();

  String blockName = '';
  double blockWorkload = 0.0;
  int workoutsCompleted = 0;
  int daysTaken = 0;
  int totalCalendarDays = 0;
  List<String> badgeAssetPaths = [];
  bool isLoading = true;
  String feedbackMessage = '';
  Map<String, double> newBig3Prs = {};


  @override
  void initState() {
    super.initState();
    _loadSummaryData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PromoPopupService().showPromoDialog(context);
    });
  }

  Future<void> _loadSummaryData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final name = await _statsService.getBlockName(widget.blockInstanceId);
    final workload = await _statsService.getBlockWorkload(widget.blockInstanceId);
    final completed = await _statsService.getCompletedWorkoutCount(widget.blockInstanceId);
    final days = await _statsService.getDaysTakenForBlock(widget.blockInstanceId);
    final calendarDays = await _statsService.getCalendarDaysForBlock(widget.blockInstanceId);
    final badges = await _statsService.getBlockEarnedBadges(userId, widget.blockInstanceId);
    final prs = await _statsService.getBigThreePRsForBlock(userId, widget.blockInstanceId);

    final expectedDays = 28;

    String feedback;
    if (calendarDays <= expectedDays) {
      feedback = "Good job! You did what you were supposed to.";
    } else if (calendarDays <= expectedDays + 14) {
      feedback = "Well, you finished a bit late, but you stuck with it.";
    } else {
      feedback = "Dang bro. Remember, consistency builds momentum.";
    }

    if (!mounted) return;
    setState(() {
      blockName = name;
      blockWorkload = workload;
      workoutsCompleted = completed;
      daysTaken = days;
      totalCalendarDays = calendarDays;
      badgeAssetPaths = badges.map((b) => b['imagePath'] as String).toList();
      feedbackMessage = feedback;
      newBig3Prs = prs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UserDashboard()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              blockName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Summary',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Text('Block Workload: ${blockWorkload.toStringAsFixed(1)} lbs'),
            Text('Workouts Completed: $workoutsCompleted'),
            Text('Days Taken: $daysTaken'),
            if (newBig3Prs.isNotEmpty) ...[
              const SizedBox(height: 30),
              const Text(
                'Big Three PRs:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...newBig3Prs.entries.map((e) =>
                  Text('${e.key}: ${e.value.toStringAsFixed(0)} lbs')),
            ],
            if (feedbackMessage.isNotEmpty)
              Text(
                feedbackMessage,
                style: TextStyle(color: Colors.green[400], fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 30),
            if (badgeAssetPaths.isNotEmpty)
              const Text(
                'Badges Earned:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            BadgeGrid(imagePaths: badgeAssetPaths),
          ],
        ),
      ),
    );
  }
}
