import 'package:flutter/material.dart';
import 'package:lift_league/models/workout.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/calculations.dart';
import 'package:lift_league/screens/block_dashboard.dart';
import 'package:lift_league/screens/user_dashboard.dart';
import 'package:lift_league/services/notifications_service.dart';
import 'package:lift_league/screens/lift_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/workout_footer.dart';
import 'package:lift_league/widgets/workout_header.dart';
import 'package:lift_league/widgets/badge_carousel.dart';
import 'package:lift_league/screens/block_summary.dart';
import 'package:lift_league/services/leaderboard_service.dart';
import 'package:lift_league/modals/numpad_modal.dart';
import 'package:lift_league/services/pr_service.dart';
import 'package:lift_league/services/performance_service.dart';
import 'package:lift_league/services/promo_popup_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WorkoutLogScreen extends StatefulWidget {
  final int workoutInstanceId;
  final int blockInstanceId;

  const WorkoutLogScreen({
    super.key,
    required this.workoutInstanceId,
    required this.blockInstanceId,
  });

  @override
  WorkoutLogScreenState createState() => WorkoutLogScreenState();
}

class WorkoutLogScreenState extends State<WorkoutLogScreen> with SingleTickerProviderStateMixin {
  late AnimationController _numpadController;
  late Animation<Offset> _numpadOffset;
  late ValueNotifier<WorkoutInstanceTotals?> workoutTotals;
  Workout? workout;
  bool isLoading = true;
  bool isNumpadOpen = false;
  String? _activeFieldKey;
  double _cachedPreviousScore = 0.0;
  Map<String, double> _startingBig3Prs = {};
  bool _isCustomBlock = false;

// You no longer need separate state values for score/workload/previousScore
// Remove buildWorkoutInstanceTotals()

  final Map<String, TextEditingController> _controllerMap = {};
  final Map<String, FocusNode> _focusMap = {};
  final Map<int, GlobalKey> _liftEntryKeys = {};


// ──────────────────────────────────────────────
// 🔁 INIT + STATE HELPERS
// ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _numpadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _numpadOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _numpadController,
      curve: Curves.easeOut,
    ));


    _setWorkoutStartTime();
    _loadWorkoutData();
    workoutTotals = ValueNotifier(null);
  }

  Future<void> _setWorkoutStartTime() async {
    final db = DBService();
    final existingWorkout = await db.getWorkoutInstanceById(widget.workoutInstanceId);
    if (existingWorkout != null && existingWorkout['startTime'] == null) {
      await db.setWorkoutStartTime(widget.workoutInstanceId);
      print("✅ Workout startTime set in DB");
    }
  }

  Future<void> _loadWorkoutData() async {
    final db = DBService();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _startingBig3Prs = await getBig3PRs(currentUser.uid);

    // Load instance rows
    final workoutInstance = await db.getWorkoutInstanceById(widget.workoutInstanceId);
    if (workoutInstance == null) {
      if (!mounted) return;
      setState(() {
        workout = null;
        isLoading = false;
      });
      return;
    }

    final blockInstance = await db.getBlockInstanceById(widget.blockInstanceId);
    if (blockInstance == null) {
      if (!mounted) return;
      setState(() {
        workout = null;
        isLoading = false;
      });
      return;
    }

    _isCustomBlock = blockInstance['customBlockId'] != null;

    final int workoutId = (workoutInstance['workoutId'] as int?) ?? 0; // 0 for custom instances

// Unified fetch: built-ins (workoutId!=null) use lift_workouts; customs pull from lift_instances.
// Shows edits immediately for custom blocks.
    final List<Map<String, Object?>> liftsFromDb =
        await DBService().getLiftsForWorkoutInstance(widget.workoutInstanceId);


    final List<Liftinfo> orderedLifts = [];
    for (final lift in liftsFromDb) {
      final int sets = (lift['sets'] as int?) ?? 3;
      final int? repsPerSet = lift['repsPerSet'] as int?;
      final String repScheme = repsPerSet != null
          ? '$sets sets x $repsPerSet reps'
          : (lift['repScheme'] as String? ?? ''); // rare legacy fallback

      final int scoreTypeInt =
          (lift['scoreType'] as num?)?.toInt() ?? SCORE_TYPE_MULTIPLIER;
      final String scoreType =
          scoreTypeInt == SCORE_TYPE_BODYWEIGHT ? 'bodyweight' : 'multiplier';

      orderedLifts.add(
        Liftinfo(
          liftId: (lift['liftId'] as num?)?.toInt() ?? 0,
          workoutInstanceId: widget.workoutInstanceId,
          // built-ins return "name"; legacy paths returned "liftName"
          liftName: (lift['liftName'] as String?) ??
              (lift['name'] as String?) ??
              'Unknown',
          repScheme: repScheme,
          numSets: sets,
          scoreMultiplier: ((lift['scoreMultiplier'] as num?) ?? 1.0).toDouble(),
          isDumbbellLift: ((lift['isDumbbellLift'] as num?) ?? 0).toInt() == 1,
          scoreType: scoreType,
          youtubeUrl: lift['youtubeUrl'] as String? ?? '',
          description: lift['description'] as String? ?? '',
          referenceLiftId: (lift['referenceLiftId'] as num?)?.toInt(),
          percentOfReference: (lift['percentOfReference'] as num?)?.toDouble(),
        ),
      );
    }



    final blockDisplayName = (blockInstance['blockName'] as String?) ?? 'Block Name';
    final workoutDisplayName = (workoutInstance['workoutName'] as String?) ?? 'Workout';

    // Build the screen model from INSTANCE data (not templates)
    workout = Workout(
      workoutInstanceId: widget.workoutInstanceId,
      blockInstanceId: blockInstance['blockInstanceId'],
      blockName: blockDisplayName,
      name: workoutDisplayName,
      lifts: orderedLifts,
      workoutScore: 0.0,
      workoutId: workoutId,
    );

    // Totals & previous score
    final workoutTotalsFromDb =
    await db.getWorkoutTotals(widget.workoutInstanceId, currentUser.uid);
    final previousScore = await db.getPreviousWorkoutScore(
      widget.workoutInstanceId,
      workout!.workoutId,
      currentUser.uid,
    );
    _cachedPreviousScore = previousScore;

    workoutTotals.value = WorkoutInstanceTotals(
      workoutScore: (workoutTotalsFromDb?['workoutScore'] as double?) ?? 0.0,
      workoutWorkload: (workoutTotalsFromDb?['workoutWorkload'] as double?) ?? 0.0,
      previousWorkoutScore: previousScore,
    );

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }


  void _showInlineNumpad(String fieldKey) {
    setState(() {
      isNumpadOpen = true;
      _activeFieldKey = fieldKey;
      _numpadController.forward();
    });
  }

  void _closeInlineNumpad() {
    setState(() {
      isNumpadOpen = false;
      _activeFieldKey = null;
      _numpadController.reverse();
    });
  }

  void _fillDown(String key) {
    final parts = key.split('_');
    if (parts.length < 3) return;

    final liftId = parts[0];
    final type = parts[1]; // 'rep' or 'weight'
    final startIndex = int.tryParse(parts[2]) ?? 0;
    final valueToFill = _controllerMap[key]?.text ?? '';

    for (int i = startIndex + 1; i < 10; i++) {
      final targetKey = '${liftId}_${type}_$i';
      if (_controllerMap.containsKey(targetKey)) {
        _controllerMap[targetKey]?.text = valueToFill;
      }
    }
  }

  Future<void> _handleNumpadPress(String value) async {
    final controller = _controllerMap[_activeFieldKey];
    if (controller == null) return;

    switch (value) {
      case 'backspace':
        if (controller.text.isNotEmpty) {
          controller.text = controller.text.substring(0, controller.text.length - 1);
        }
        break;
      case 'done':
        if (_activeFieldKey != null) {
          final liftId = int.tryParse(_activeFieldKey!.split('_').first);
          if (liftId != null) {
            final key = _liftEntryKeys[liftId];
            if (key?.currentState != null) {
              final dynamic state = key!.currentState;
              await state.finalizeLift();
            }
          }
        }
        _closeInlineNumpad();
        break;
      case 'decimal':
        if (!controller.text.contains('.')) controller.text += '.';
        break;
      case 'fillDown':
        _fillDown(_activeFieldKey ?? '');
        break;
      case 'arrowDown':
        _shiftFocus(_activeFieldKey ?? '', down: true);
        break;
      case 'arrowRight':
        _shiftFocus(_activeFieldKey ?? '', right: true);
        break;
      default:
        controller.text += value;
    }

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _shiftFocus(String key, {bool down = false, bool right = false}) {
    final parts = key.split('_');
    if (parts.length < 3) return;

    final liftId = parts[0];
    final type = parts[1];
    int index = int.tryParse(parts[2]) ?? 0;

    String? nextKey;
    if (down) {
      nextKey = '${liftId}_${type}_${index + 1}';
    } else if (right) {
      nextKey = '${liftId}_${type == 'rep' ? 'weight' : 'rep'}_$index';
    }

    if (_focusMap.containsKey(nextKey)) {
      _focusMap[nextKey]!.requestFocus();
      _activeFieldKey = nextKey;
    }
  }

// ──────────────────────────────────────────────
// 🧠 LOGIC: LIFT + WORKOUT TOTAL HANDLERS
// ──────────────────────────────────────────────
  Future<void> _handleUpdateStoredDataDirect(Liftinfo lift, List<String> reps, List<String> weights) async {
    await _syncLiftTotalsFromLift(lift, reps, weights);
  }

  Future<void> _syncLiftTotalsFromLift(Liftinfo lift, List<String> reps, List<String> weights) async {
    if (reps.isEmpty || weights.isEmpty) {
      print("⚠️ Skipping lift total update — empty reps or weights");
      return;
    }

    final db = DBService();
    final repsControllers = reps.map((r) => TextEditingController(text: r)).toList();
    final weightControllers = weights.map((w) => TextEditingController(text: w)).toList();

    final totalReps = getLiftReps(repsControllers, isDumbbellLift: lift.isDumbbellLift);
    final totalWorkload = getLiftWorkload(repsControllers, weightControllers, isDumbbellLift: lift.isDumbbellLift);
    final score = getLiftScore(repsControllers, weightControllers, lift.scoreMultiplier,
        isDumbbellLift: lift.isDumbbellLift, scoreType: lift.scoreType);

    await db.writeLiftTotalsDirectly(
      workoutInstanceId: lift.workoutInstanceId!,
      liftId: lift.liftId,
      liftReps: totalReps,
      liftWorkload: totalWorkload,
      liftScore: score,
    );
  }

// ──────────────────────────────────────────────
// ✅ WORKOUT COMPLETION + NAVIGATION
// ──────────────────────────────────────────────

  Future<void> _markWorkoutComplete() async {

    final db = DBService();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 1️⃣ Sync totals & Firestore
    await db.writeWorkoutTotalsDirectly(
      workoutInstanceId: widget.workoutInstanceId,
      userId: userId,
      syncToCloud: true,
    );
    await db.syncWorkoutTotalsToFirestore(userId);

    // 2️⃣ Complete workout + check block
    final blockJustFinished = await db.completeWorkoutAndCheckBlock(
      workoutInstanceId: widget.workoutInstanceId,
      blockInstanceId: widget.blockInstanceId,
      userId: userId,
    );

    // 3️⃣ Leaderboard
    final blockId = await db.getBlockIdFromInstance(widget.blockInstanceId);
    await syncBestLeaderboardEntryForBlock(userId: userId, blockId: blockId);

    // 🎯 Consistency check
    final summary = await PerformanceService().consistency(
      userId: userId,
      blockInstanceId: widget.blockInstanceId,
    );
    if (summary.percent == 100) {
      NotificationService().showSimpleNotification(
        "Great job!",
        "You completed all workouts for week ${summary.currentWeek}!",
      );
    }

    // 4️⃣ Badges
    final earnedBadges = await db.checkForEarnedBadges(userId: userId);

    // 5️⃣ Auto-clink with badges
    final badgePaths = earnedBadges
        .map<String>((b) => 'assets/images/badges/${b['image'] ?? 'badge_default.png'}')
        .toList();
    await db.postAutoClinkAfterWorkout(userId, badgeImagePaths: badgePaths);

    // 5️⃣b Check for new Big 3 PRs
    final endingPrs = await getBig3PRs(userId);
    final prUpdates = <String>[];
    for (final lift in ['Bench Press', 'Squats', 'Deadlift']) {
      final start = _startingBig3Prs[lift] ?? 0;
      final end = endingPrs[lift] ?? 0;
      if (end > start) {
        prUpdates.add('New $lift PR - ${end.toStringAsFixed(0)}');
      }
    }
    if (prUpdates.isNotEmpty) {
      final message = prUpdates.join(' & ');
      await db.postPRClink(userId, message);
    }

    // 6️⃣ Remaining count
    final remaining = await db.getRemainingUnfinishedWorkouts(widget.blockInstanceId);

    // 7️⃣ Bail if unmounted
    if (!mounted) return;

    // 8️⃣ BADGE CAROUSEL always comes first if there are earned badges
    if (earnedBadges.isNotEmpty) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 204),
        pageBuilder: (_, __, ___) => BadgeCarousel(
          earnedBadges: earnedBadges,
          // We'll continue navigation in the next lines, not here
          onComplete: () {}, // We handle navigation below instead
        ),
      );
    }
    // 9️⃣ After carousel, decide what to show next:
    if (!mounted) return;
    if (blockJustFinished) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 204),
        pageBuilder: (_, __, ___) => BlockSummaryScreen(
          blockInstanceId: widget.blockInstanceId,
        ),
      );
    } else {
      _navigateAfterWorkout(remaining);
    }

    if (mounted && kIsWeb) {
      await PromoPopupService().showPromoDialog(context);
    }
  }

  void _navigateAfterWorkout(int remaining) {
    if (!mounted) return;

    if (remaining == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BlockSummaryScreen(blockInstanceId: widget.blockInstanceId),
        ),
            (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BlockDashboard(blockInstanceId: widget.blockInstanceId),
        ),
            (route) => false,
      );
    }
  }

  void _navigateHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UserDashboard()),
          (route) => false,
    );
  }

  void _navigateBack(BuildContext context, int blockInstanceId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => BlockDashboard(blockInstanceId: blockInstanceId)),
          (route) => false,
    );
  }

// ──────────────────────────────────────────────
// ✅ THE BUILD
// ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : workout == null
          ? const Center(
        child: Text("Workout not found.", style: TextStyle(color: Colors.white)),
      )
          : Column(
        children: [
          WorkoutHeader(
            blockName: workout!.blockName,
            workoutName: workout!.name,
            onBack: () => _navigateBack(context, workout!.blockInstanceId),
            onHome: () => _navigateHome(context),
          ),
          Expanded(child: _buildLiftList()),

          if (isNumpadOpen)
            SlideTransition(
              position: _numpadOffset,
              child: NumpadModal(onKeyPressed: _handleNumpadPress),
            ),

          SafeArea(
            child: ValueListenableBuilder<WorkoutInstanceTotals?>(
              valueListenable: workoutTotals,
              builder: (context, totals, _) {
                if (totals == null) {
                  return const SizedBox.shrink(); // or a loading widget
                }

                return WorkoutFooter(
                  workoutScore: totals.workoutScore,
                  totalWorkload: totals.workoutWorkload,
                  previousScore: totals.previousWorkoutScore,
                );
              },
            ),
          ),

        ],
      )
    );
  }

  Widget _buildLiftList() {
    if (workout!.lifts.isEmpty) {
      return const Center(
        child: Text("No lifts available", style: TextStyle(color: Colors.white)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        ...workout!.lifts.asMap().entries.map((entry) {
          final lift = entry.value;
          final index = entry.key;

          return StatefulBuilder(
            builder: (context, setLocalState) {
              final liftKey = _liftEntryKeys.putIfAbsent(
                  lift.liftId, () => GlobalKey());
              return LiftEntry(
                key: liftKey,
                blockInstanceId: widget.blockInstanceId,
                blockName: workout!.blockName,
                liftIndex: index,
                lift: lift,
                blockId: widget.blockInstanceId,
                workoutInstanceId: widget.workoutInstanceId,
                controllerMap: _controllerMap,
                focusMap: _focusMap,
                openNumpad: _showInlineNumpad,
                onUpdateStoredDataDirect: _handleUpdateStoredDataDirect,
                onLiftDataChanged: (score, workload, reps, weights) async {
                  final db = DBService();
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;

                  final repsControllers = reps.map((r) => TextEditingController(text: r)).toList();
                  final totalReps = getLiftReps(
                    repsControllers,
                    isDumbbellLift: workout!.lifts[index].isDumbbellLift,
                  );

                  await db.writeLiftTotalsDirectly(
                    workoutInstanceId: workout!.workoutInstanceId,
                    liftId: workout!.lifts[index].liftId,
                    liftReps: totalReps,
                    liftWorkload: workload,
                    liftScore: score,
                  );

                  // ✅ Only write to SQLite during logging — skip Firestore
                  await db.writeWorkoutTotalsDirectly(
                    workoutInstanceId: workout!.workoutInstanceId,
                    userId: currentUser.uid,
                    syncToCloud: false,
                  );

                  final updatedTotals = await db.getWorkoutTotals(
                    workout!.workoutInstanceId,
                    currentUser.uid,
                  );

                  if (updatedTotals != null) {
                    workoutTotals.value = WorkoutInstanceTotals(
                      workoutScore: updatedTotals['workoutScore'] as double,
                      workoutWorkload: updatedTotals['workoutWorkload'] as double,
                      previousWorkoutScore: _cachedPreviousScore,
                    );
                  }
                },
                hideDescription: _isCustomBlock,
              );
            },
          );
        }),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton(
            onPressed: _markWorkoutComplete,
            child: const Text("Finish Workout"),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  @override
  void dispose() {
    _numpadController.dispose();
    super.dispose();
  }
}
