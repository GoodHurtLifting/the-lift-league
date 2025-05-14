import 'package:flutter/material.dart';
import 'package:lift_league/models/workout.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/calculations.dart';
import 'package:lift_league/screens/block_dashboard.dart';
import 'package:lift_league/screens/user_dashboard.dart';
import 'package:lift_league/screens/lift_entry.dart';
import 'package:lift_league/data/block_data.dart';
import 'package:lift_league/data/workout_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/workout_footer.dart';
import 'package:lift_league/widgets/workout_header.dart';
import 'package:lift_league/widgets/badge_carousel.dart';
import 'package:lift_league/screens/block_summary.dart';
import 'package:lift_league/services/leaderboard_service.dart';
import 'package:lift_league/modals/numpad_modal.dart';

class WorkoutLogScreen extends StatefulWidget {
  final int workoutInstanceId;
  final int blockInstanceId;

  const WorkoutLogScreen({
    super.key,
    required this.workoutInstanceId,
    required this.blockInstanceId,
  });

  @override
  _WorkoutLogScreenState createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> with SingleTickerProviderStateMixin {
  late AnimationController _numpadController;
  late Animation<Offset> _numpadOffset;
  late ValueNotifier<WorkoutInstanceTotals?> workoutTotals;
  Workout? workout;
  bool isLoading = true;
  bool isNumpadOpen = false;
  String? _activeFieldKey;
  double _cachedPreviousScore = 0.0;

// You no longer need separate state values for score/workload/previousScore
// Remove buildWorkoutInstanceTotals()

  final Map<String, TextEditingController> _controllerMap = {};
  final Map<String, FocusNode> _focusMap = {};


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

    final workoutInstance = await db.getWorkoutInstanceById(
        widget.workoutInstanceId);
    if (workoutInstance == null) {
      setState(() {
        workout = null;
        isLoading = false;
      });
      return;
    }

    final blockInstance = await db.getBlockInstanceById(widget.blockInstanceId);
    if (blockInstance == null) {
      setState(() {
        workout = null;
        isLoading = false;
      });
      return;
    }

    final int workoutId = (workoutInstance['workoutId'] as num).toInt();
    final workoutDefinition = workoutDataList.firstWhere(
          (w) => w['workoutId'] == workoutId,
      orElse: () => {'name': 'Unknown Workout'},
    );

    final List<int> liftIds = List<int>.from(
        workoutDefinition['liftIds'] ?? []);
    final block = blockDataList.firstWhere(
          (b) => b['blockId'] == blockInstance['blockId'],
      orElse: () => {'blockName': 'Block Name'},
    );

    // Prepare lifts
    final List<Liftinfo> orderedLifts = [];
    for (final id in liftIds) {
      final liftData = await db.getLiftById(id);
      if (liftData != null) {
        orderedLifts.add(
          Liftinfo(
            liftId: id,
            workoutInstanceId: widget.workoutInstanceId,
            liftName: liftData['liftName'] ?? 'Unknown',
            repScheme: liftData['repScheme'] ?? '',
            numSets: liftData['numSets'] ?? 3,
            scoreMultiplier: (liftData['scoreMultiplier'] ?? 1.0).toDouble(),
            isDumbbellLift: liftData['isDumbbellLift'] == 1,
            scoreType: liftData['scoreType'] ?? 'multiplier',
            youtubeUrl: liftData['youtubeUrl'],
            description: liftData['description'] ?? '',
            referenceLiftId: liftData['referenceLiftId'],
            percentOfReference: (liftData['percentOfReference'] as num?)
                ?.toDouble(),
          ),
        );
      }
    }

    // Construct the workout object
    workout = Workout(
      workoutInstanceId: widget.workoutInstanceId,
      blockInstanceId: blockInstance['blockInstanceId'],
      blockName: block['blockName'] ?? 'Block Name',
      name: workoutDefinition['workoutName'] ?? 'Workout Name',
      lifts: orderedLifts,
      workoutScore: 0.0,
      // Can be 0.0 or removed if unused
      workoutId: workoutDefinition['workoutId'],
    );

// Get workout totals and previous score from DB
    final workoutTotalsFromDb = await db.getWorkoutTotals(
        widget.workoutInstanceId, currentUser.uid);
    final previousScore = await db.getPreviousWorkoutScore(
        widget.workoutInstanceId, workout!.workoutId, currentUser.uid);
    _cachedPreviousScore = previousScore;

// Update ValueNotifier (footer)
    workoutTotals.value = WorkoutInstanceTotals(
      workoutScore: workoutTotalsFromDb?['workoutScore'] as double? ?? 0.0,
      workoutWorkload: workoutTotalsFromDb?['workoutWorkload'] as double? ?? 0.0,
      previousWorkoutScore: previousScore,
    );

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

  void _handleNumpadPress(String value) {
    final controller = _controllerMap[_activeFieldKey];
    if (controller == null) return;

    switch (value) {
      case 'backspace':
        if (controller.text.isNotEmpty) {
          controller.text = controller.text.substring(0, controller.text.length - 1);
        }
        break;
      case 'done':
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

    // ✅ Ensure workout totals are synced and Firestore is updated
    await db.writeWorkoutTotalsDirectly(
      workoutInstanceId: widget.workoutInstanceId,
      userId: userId,
      syncToCloud: true,
    );

    await db.syncWorkoutTotalsToFirestore(userId);

    await db.completeWorkoutAndCheckBlock(
      workoutInstanceId: widget.workoutInstanceId,
      blockInstanceId: widget.blockInstanceId,
      userId: userId,
      context: context,
    );

    final blockId = await db.getBlockIdFromInstance(widget.blockInstanceId);

    await syncBestLeaderboardEntryForBlock(
      userId: userId,
      blockId: blockId,
    );

    final remaining = await db.getRemainingUnfinishedWorkouts(widget.blockInstanceId);

    final earnedBadges = await db.checkForEarnedBadges(userId: userId);

    if (!context.mounted) return;

    if (earnedBadges.isNotEmpty) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.8),
        pageBuilder: (_, __, ___) => BadgeCarousel(
          earnedBadges: earnedBadges,
          onComplete: () => _navigateAfterWorkout(remaining),
        ),
      );
    } else {
      _navigateAfterWorkout(remaining);
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
            top: false,
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
              return LiftEntry(
                key: ValueKey('lift_${widget.workoutInstanceId}_${index}_${lift.liftId}'),
                blockInstanceId: widget.blockInstanceId,
                blockName: workout!.blockName,
                liftIndex: index,
                lift: lift,
                blockId: widget.blockInstanceId,
                workoutInstanceId: widget.workoutInstanceId,
                numSets: lift.numSets,
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
