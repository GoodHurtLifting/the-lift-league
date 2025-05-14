import 'package:flutter/material.dart';
import 'package:lift_league/screens/workout_log.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/models/workout.dart';
import 'package:lift_league/screens/user_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/screens/leaderboard_screen.dart';


class BlockDashboard extends StatefulWidget {
  final int blockInstanceId;

  const BlockDashboard({super.key, required this.blockInstanceId});

  @override
  _BlockDashboardState createState() => _BlockDashboardState();
}

class _BlockDashboardState extends State<BlockDashboard> {
  late int currentBlockInstanceId;
  List<Workout> workouts = [];
  bool isLoading = true;
  String blockName = "";
  Map<String, double> _bestScoresByType = {}; // ✅ dynamic scores for any workout types
  double _blockScore = 0.0; // ✅ sum of best scores
  String scheduleType = 'standard';
  bool isFirstLoad = false;

  @override
  void initState() {
    super.initState();
    currentBlockInstanceId = widget.blockInstanceId;

    // ✅ Load block name and workouts
    Future.microtask(() async {
      await _loadBlockName();
      await _loadBlockRuns();
      await _loadWorkouts();
    });
  }

  // ✅ Fetch the block name dynamically
  Future<void> _loadBlockName() async {
    final db = DBService();
    Map<String, dynamic>? blockData = await db.getBlockInstanceById(currentBlockInstanceId);

    if (blockData != null) {
      final int blockId = blockData['blockId'];
      final String fetchedScheduleType = await db.getScheduleType(blockId); // ← pulls from blocks table

      setState(() {
        blockName = blockData['blockName'];
        scheduleType = fetchedScheduleType; // ← ensures correct display for ppl_plus, etc.
      });
    }
  }
  List<int> blockRunNumbers = [];
  int currentRunNumber = 1;
  Map<int, int> runInstanceMap = {}; // runNumber → blockInstanceId

  Future<void> _loadBlockRuns() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final db = DBService();
    final rawInstances = await db.getBlockInstancesByBlockName(blockName, userId);
    final instances = rawInstances.toList(); // make mutable

    // Order by blockInstanceId
    instances.sort((a, b) => a['blockInstanceId'].compareTo(b['blockInstanceId']));

    runInstanceMap.clear();
    blockRunNumbers.clear();

    for (int i = 0; i < instances.length; i++) {
      final runNumber = i + 1;
      final instanceId = instances[i]['blockInstanceId'];
      runInstanceMap[runNumber] = instanceId;
      blockRunNumbers.add(runNumber);

      if (instanceId == currentBlockInstanceId) {
        currentRunNumber = runNumber;
      }
    }

    setState(() {}); // Refresh display
  }


  Future<void> _loadWorkouts() async {
    final db = DBService();
    List<Map<String, dynamic>> workoutData = await db.getWorkoutInstancesByBlock(currentBlockInstanceId);

    // If no workouts exist yet, insert them first
    if (workoutData.isEmpty) {
      setState(() {
        isFirstLoad = true;
      });

      await db.insertWorkoutInstancesForBlock(currentBlockInstanceId);

      workoutData = await db.getWorkoutInstancesByBlock(currentBlockInstanceId);

      setState(() {
        isFirstLoad = false;
      });
    }

    final Map<String, double> bestScoresByType = {};
    final List<Workout> loadedWorkouts = [];

    for (var w in workoutData) {
      final int workoutInstanceId = w['workoutInstanceId'];
      final String workoutName = (w['workoutName'] ?? '').toString().trim();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch actual score from workout_totals
      final totals = await db.getWorkoutTotals(workoutInstanceId, user.uid);
      final double workoutScore = (totals?['workoutScore'] as num?)?.toDouble() ?? 0.0;

      // Use full name or parse to base (optional)
      final String typeName = workoutName;

      // Keep best score per workout type
      if (!bestScoresByType.containsKey(typeName) || workoutScore > bestScoresByType[typeName]!) {
        bestScoresByType[typeName] = workoutScore;
      }

      loadedWorkouts.add(
        Workout(
          workoutInstanceId: workoutInstanceId,
          blockInstanceId: currentBlockInstanceId,
          blockName: blockName.isNotEmpty ? blockName : 'Workout Block',
          name: workoutName,
          lifts: [],
          workoutScore: workoutScore,
          workoutId: 0,
        ),
      );
    }

    setState(() {
      workouts = loadedWorkouts;
      _bestScoresByType = bestScoresByType;
      isLoading = false;
    });

    print("✅ Best scores by workout type: $_bestScoresByType");

    await _loadBlockTotals();
  }

  Future<void> _loadBlockTotals() async {
    final db = DBService();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Or handle accordingly
    // And in _loadBlockTotals():
    final totals = await db.getBlockTotals(currentBlockInstanceId, user.uid);

    if (totals != null) {
      setState(() {
        _blockScore = (totals['blockScore'] as num?)?.toDouble() ?? 0.0;
      });
      print("✅ Loaded block score from block_totals: $_blockScore");
    } else {
      setState(() {
        _blockScore = 0.0;
      });
      print("⚠️ No block_totals entry found for Block $currentBlockInstanceId");
    }
  }


  // ✅ Restart the block (creates a new instance)
  Future<void> _restartBlock() async {
    if (blockName.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int newBlockInstanceId = await DBService().insertNewBlockInstance(blockName, user.uid);
    await DBService().insertWorkoutInstancesForBlock(newBlockInstanceId);

    setState(() {
      currentBlockInstanceId = newBlockInstanceId;
    });

    // ✅ Navigate to the new instance
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BlockDashboard(blockInstanceId: newBlockInstanceId),
      ),
    );
  }

  void navigateToWorkout(BuildContext context, int workoutInstanceId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutLogScreen(
          workoutInstanceId: workoutInstanceId,
          blockInstanceId: currentBlockInstanceId,
        ),
      ),
    );
    // ✅ Reload workouts to show updated scores
    await _loadWorkouts();
  }

  @override

  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UserDashboard()),
              );
            },
          ),
          title: Text(
            workouts.isNotEmpty ? workouts.first.blockName.toUpperCase() : "BLOCK",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.replay, color: Colors.green),
              onPressed: _restartBlock,
            ),
          ],
        ),
        body:  isLoading || isFirstLoad
            ? const Center(
          child: Text(
            "Loading workouts for the first time...",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        )
        : Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (blockRunNumbers.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Block Runs: ", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ...blockRunNumbers.map((runNumber) {
                        final isCurrent = runNumber == currentRunNumber;
                        return GestureDetector(
                          onTap: () {
                            if (!isCurrent) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BlockDashboard(blockInstanceId: runInstanceMap[runNumber]!),
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.red : Colors.grey[800],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$runNumber',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        );
                      })
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),

              const Text(
                "The 411",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Leaderboard Scores Placeholder (Replace with Actual Data Later)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaderboardScreen(blockId: currentBlockInstanceId),
                    ),
                  );
                },
                child: const Text(
                  'LEADERBOARD SCORES',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._bestScoresByType.entries
                  .where((entry) {
                final name = entry.key.toUpperCase();
                return !name.contains("RECOVERY");
              })
                  .map((entry) {
                return Text(
                  "Best ${entry.key}: ${entry.value.toStringAsFixed(1)}",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                );
              }),
              Text(
                "Block Total: ${_blockScore.toStringAsFixed(1)}",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),


              const SizedBox(height: 20),

              // ✅ Display Workouts Organized by Weeks
              Expanded(
                child: ListView(
                  children: scheduleType == 'ppl_plus'
                      ? List.generate((workouts.length / 3).ceil(), (roundIndex) {
                    final roundWorkouts = workouts.skip(roundIndex * 3).take(3).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ROUND ${roundIndex + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...roundWorkouts.map((workout) {
                          final cleanedName = workout.name.replaceAll(RegExp(r' - Round \d+'), '');
                          final scoreText = workout.workoutScore.toStringAsFixed(1);
                          return GestureDetector(
                            onTap: () => navigateToWorkout(context, workout.workoutInstanceId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text(
                                '$cleanedName : $scoreText',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    );
                  })
                  // ✅ Display Workouts Organized into 4 Weeks (3 per week)
                    :List.generate(4, (weekIndex) {
                    final int workoutsPerWeek = (workouts.length / 4).ceil();
                    final int start = weekIndex * workoutsPerWeek;
                    final int end = (start + workoutsPerWeek).clamp(0, workouts.length);

                    if (start >= workouts.length) {
                      return const SizedBox.shrink(); // 👈 skip rendering this week entirely
                    }

                    final List<Workout> weekWorkouts = workouts.sublist(
                      start,
                      end.clamp(start, workouts.length), // 👈 ensures valid sublist range
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "WEEK ${weekIndex + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (weekWorkouts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              "No workouts found for this week.",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ...weekWorkouts.map((workout) {
                            final scoreText = workout.workoutScore.toStringAsFixed(1);
                            return GestureDetector(
                              onTap: () => navigateToWorkout(context, workout.workoutInstanceId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  '${workout.name} : $scoreText',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 20),
                      ],
                    );
                  })
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
