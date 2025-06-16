import 'package:flutter/material.dart';
import 'package:lift_league/models/workout.dart';
import 'package:lift_league/services/calculations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/badge_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/pr_service.dart';

class LiftEntry extends StatefulWidget {
  final int liftIndex;
  final Liftinfo lift;
  final int blockId;
  final int workoutInstanceId;
  final int numSets;
  final int blockInstanceId;
  final String blockName;
  final Map<String, TextEditingController> controllerMap;
  final Map<String, FocusNode> focusMap;
  final Function(String fieldKey) openNumpad;
  final Function(double score, double workload, List<String> reps, List<String> weights)? onLiftDataChanged;
  final Function(Liftinfo lift, List<String> reps, List<String> weights)? onUpdateStoredDataDirect;


  const LiftEntry({
    super.key,
    required this.liftIndex,
    required this.lift,
    required this.blockId,
    required this.workoutInstanceId,
    required this.numSets,
    required this.blockInstanceId,
    required this.blockName,
    required this.controllerMap,
    required this.focusMap,
    required this.openNumpad,
    this.onUpdateStoredDataDirect,
    required this.onLiftDataChanged,
  });

  @override
  _LiftEntryState createState() => _LiftEntryState();
}

class _LiftEntryState extends State<LiftEntry> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late List<TextEditingController> _repsControllers = [];
  late List<TextEditingController> _weightControllers = [];
  List<String> _prevReps = List.filled(5, "-"); // Default placeholder for 5 sets
  List<String> _prevWeights = List.filled(5, "-"); // Default placeholder for 5 sets
  int _prevTotalReps = 0;
  double _prevTotalWeight = 0.0;
  double _prevLiftScore = 0.0;
  double _liftScore = 0.0;
  double _liftWorkload = 0.0;
  double? _recommendedWeight;
  bool isLoading = true;
  String liftName = "";
  String repScheme = "";
  String youtubeUrl = "";
  String description = "";
  int numSets = 1; // Default (will be fetched)
  double scoreMultiplier = 0.0;
  String scoreType = 'multiplier';
  bool isDumbbellLift = false;


  @override
  void initState() {
    super.initState();
    _loadLiftDetails();
  }

  void _recalculateLiftTotals() {

    _liftScore = getLiftScore(
      _repsControllers,
      _weightControllers,
      scoreMultiplier,
      isDumbbellLift: isDumbbellLift,
      scoreType: scoreType,
    );

    _liftWorkload = getLiftWorkload(
      _repsControllers,
      _weightControllers,
      isDumbbellLift: isDumbbellLift,
    );
  }

  void _loadLiftDetails() async {
    // ✔️ Use data passed in from parent instead of refetching
    liftName = widget.lift.liftName;
    repScheme = widget.lift.repScheme;
    youtubeUrl = widget.lift.youtubeUrl;
    description = widget.lift.description;
    numSets = widget.lift.numSets;
    scoreMultiplier = widget.lift.scoreMultiplier;
    isDumbbellLift = widget.lift.isDumbbellLift;
    scoreType = widget.lift.scoreType;

    _initializeControllers();
    _recalculateLiftTotals(); // ✅ Force initial totals even if fields pre-filled
    await _loadSavedData();

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    if (_repsControllers.isNotEmpty && _weightControllers.isNotEmpty) {
      return;
    }

    _repsControllers = List.generate(widget.numSets, (index) {
      final controller = TextEditingController();
      widget.controllerMap['${widget.lift.liftId}_rep_$index'] = controller;
      widget.focusMap['${widget.lift.liftId}_rep_$index'] = FocusNode();
      controller.addListener(_onFieldChanged);
      return controller;
    });

    _weightControllers = List.generate(widget.numSets, (index) {
      final controller = TextEditingController();
      widget.controllerMap['${widget.lift.liftId}_weight_$index'] = controller;
      widget.focusMap['${widget.lift.liftId}_weight_$index'] = FocusNode();
      controller.addListener(_onFieldChanged);
      return controller;
    });
  }

  void _onFieldChanged() {
    // 🚫 Do nothing here. Calculations and DB updates are triggered
    // when the user presses the Done button in the numpad modal.
  }

  Future<void> _checkLunchLadyBadge() async {
    final liftName = widget.lift.liftName;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (liftName == 'Bench Press' || liftName == 'Squats' || liftName == 'Deadlift') {
      final weights = _weightControllers
          .map((c) => double.tryParse(c.text) ?? 0)
          .toList();
      final maxWeight = weights.isNotEmpty ? weights.reduce((a, b) => a > b ? a : b).toDouble() : 0.0;

      if (maxWeight > 0) {
        await BadgeService().checkAndAwardLunchLadyBadge(
          userId: userId,
          liftName: liftName,
          weight: maxWeight,
        );
        await updateBig3PR(
          userId: userId,
          liftName: liftName,
          weightUsed: maxWeight,
        );
      }
    }
  }

  Future<void> _loadSavedData() async {
    final db = DBService();

    final savedData = await db.getLiftEntries(widget.workoutInstanceId, widget.lift.liftId);
    if (savedData.isNotEmpty) {
      for (var set in savedData) {
        int setIndex = set['setIndex'] - 1;
        if (setIndex >= 0 && setIndex < numSets) {
          if (_repsControllers[setIndex].text.isEmpty) {
            _repsControllers[setIndex].text = set['reps'] == 0 ? "" : set['reps'].toString();
          }
          if (_weightControllers[setIndex].text.isEmpty) {
            double weight = set['weight'] ?? 0.0;
            _weightControllers[setIndex].text =
            weight == 0.0 ? "" : (weight % 1 == 0 ? weight.toInt().toString() : weight.toString());
          }
        }
      }
    }

    // ✅ Load previous lift data
    final previousData = await db.getPreviousLiftEntry(widget.workoutInstanceId, widget.lift.liftId);

    if (previousData.isNotEmpty) {
      _prevReps = List.generate(numSets, (i) =>
      (i < previousData.length) ? (previousData[i]['reps'] ?? 0).toString() : "-");

      _prevWeights = List.generate(numSets, (i) {
        if (i >= previousData.length) return "-";
        double weight = previousData[i]['weight'] ?? 0.0;
        return (weight % 1 == 0) ? weight.toInt().toString() : weight.toString();
      });

      _prevTotalReps = 0;
      _prevTotalWeight = 0.0;

      for (var item in previousData) {
        final reps = (item['reps'] ?? 0) as num;
        final weight = (item['weight'] ?? 0.0) as num;
        _prevTotalReps += reps.toInt();
        _prevTotalWeight += reps.toDouble() * weight.toDouble();
      }
    } else {
      print("⚠️ No previous data found for liftId: ${widget.lift.liftId}");
      _prevReps = List.generate(numSets, (_) => "-");
      _prevWeights = List.generate(numSets, (_) => "-");
      _prevTotalReps = 0;
      _prevTotalWeight = 0.0;
    }

    // ✅ Fetch the previous lift score directly from the lift_totals table
    final previousScore = await db.getPreviousLiftScore(widget.workoutInstanceId, widget.lift.liftId);
    _prevLiftScore = previousScore;

    if (widget.lift.referenceLiftId != null && widget.lift.percentOfReference != null) {
      final refWeight = await db.getAverageWeightForLift(widget.lift.referenceLiftId!);
      print("📊 RefLiftId: ${widget.lift.referenceLiftId}, %: ${widget.lift.percentOfReference}, Avg: $refWeight");
      if (refWeight != null && refWeight > 0) {
        _recommendedWeight = (refWeight * widget.lift.percentOfReference!).roundToDouble();
      } else {
        _recommendedWeight = null; // Show dash instead of 0
      }
    }
  }

  void updateStoredData() async {
    final db = DBService();

    final reps = _repsControllers.map((c) => c.text).toList();
    final weights = _weightControllers.map((c) => c.text).toList();

    bool hasValidEntry = false;

    for (int i = 0; i < numSets; i++) {
      final int parsedReps = int.tryParse(reps[i]) ?? 0;
      final double parsedWeight = double.tryParse(weights[i]) ?? 0.0;

      if (parsedReps > 0 || parsedWeight > 0) {
        hasValidEntry = true;

        await db.saveLiftEntry(
          workoutInstanceId: widget.workoutInstanceId,
          liftId: widget.lift.liftId,
          setIndex: i + 1,
          reps: parsedReps,
          weight: parsedWeight,
        );
      }
    }

    if (!mounted || !hasValidEntry) return;

    // 🧠 Update totals in the DB
    await db.updateLiftTotals(widget.workoutInstanceId, widget.lift.liftId);

    await db.activateBlockInstanceIfNeeded(
      widget.blockInstanceId,
      FirebaseAuth.instance.currentUser!.uid,
      widget.blockName,
    );

    // Defer the callbacks to after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUpdateStoredDataDirect?.call(widget.lift, reps, weights);
    });

    await _checkLunchLadyBadge();
  }

  void updateTotals() {
    setState(() {}); // ✅ Forces UI to refresh with updated totals
  }

  // 🔒 Public method called when the numpad "Done" button is pressed
  // to force calculation and persistence of lift data.
  void finalizeLift() {
    _recalculateLiftTotals();
    updateStoredData();

    widget.onLiftDataChanged?.call(
      _liftScore,
      _liftWorkload,
      _repsControllers.map((c) => c.text).toList(),
      _weightControllers.map((c) => c.text).toList(),
    );

    updateTotals();
  }

  void _openYouTubeVideo() async {
    if (youtubeUrl.isEmpty) return;
    try {
      final Uri url = Uri.parse(youtubeUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch $youtubeUrl");
      }
    } catch (e) {
      debugPrint("Error launching YouTube URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        SizedBox(height: 10),
        GestureDetector(
          onTap: _openYouTubeVideo,
          child: Text(liftName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline, decorationColor: Colors.blue)),
        ),
        Text(repScheme, style: const TextStyle(color: Colors.white, fontSize: 18)),
        Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.left),

        SizedBox(height: 10),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.1),  // Set #
            1: FlexColumnWidth(1.2),  // Reps
            2: FlexColumnWidth(0.4),  // Placeholder "X"
            3: FlexColumnWidth(1.4),  // Weight
            4: FlexColumnWidth(0.05),  // ✅ Slim Solid Divider Column
            5: FlexColumnWidth(1),    // Previous Reps
            6: FlexColumnWidth(0.4),  // Placeholder "X"
            7: FlexColumnWidth(1.2),  // Previous Weight
          },
          children: [
            // Header Row
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("Reps", style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("Weight (lbs)", style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center)),
                Container(
                  height: 40, // ✅ Matches row height
                  constraints: BoxConstraints(minWidth: 8, maxWidth: 12), // ✅ Prevents layout errors
                  color: Colors.black, // ✅ Ensures correct grey shade
                ),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("Prev Reps", style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    (widget.lift.referenceLiftId != null) ? "Recommended" : "Prev Weight",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // Data Entry Rows
            ...List.generate(widget.lift.numSets, (index) => TableRow(
              children: [
                // ✅ Set #
                Padding(padding: const EdgeInsets.all(8.0), child: Text("Set ${index + 1}", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),

                // ✅ Reps Entry (Dark Greyish-Green with Bottom Border)
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2E4F40), // ✅ Dark Greyish-Green
                    border: Border(bottom: BorderSide(color: Colors.white70, width: 1)), // ✅ White bottom border
                  ),
                  child: TextField(
                    key: ValueKey('reps_${widget.liftIndex}_$index'),
                    controller: _repsControllers[index],
                    focusNode: widget.focusMap['${widget.lift.liftId}_rep_$index'],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.none,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onTap: () => widget.openNumpad('${widget.lift.liftId}_rep_$index'),
                  ),
                ),

                // Placeholder
                Padding(padding: const EdgeInsets.all(8.0), child: Text("X", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),

                // ✅ Weight Entry (Dark Greyish-Green with Bottom Border)
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2E4F40), // ✅ Dark Greyish-Green
                    border: Border(bottom: BorderSide(color: Colors.white70, width: 1)), // ✅ White bottom border
                  ),
                  child: TextField(
                    key: ValueKey('weight_${widget.liftIndex}_$index'),
                    controller: _weightControllers[index],
                    focusNode: widget.focusMap['${widget.lift.liftId}_weight_$index'],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.none,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onTap: () => widget.openNumpad('${widget.lift.liftId}_weight_$index'),
                  ),
                ),

                // ✅ COLUMN 5 DIVIDER (Thinner & Consistent Height)
                Container(
                  height: 40,
                  constraints: BoxConstraints(minWidth: 6, maxWidth: 10),
                  color: Colors.black, // ✅ Divider Color
                ),

                // ✅ Previous Reps Placeholder (Greyed Out)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _prevReps[index],
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("X", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                // ✅ Previous Weight Placeholder (Greyed Out)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.lift.referenceLiftId != null
                        ? (_recommendedWeight?.toStringAsFixed(0) ?? "-")
                        : (_prevWeights[index].contains('.') && _prevWeights[index].split('.').last != '0'
                        ? _prevWeights[index]
                        : double.tryParse(_prevWeights[index])?.toStringAsFixed(0) ?? '-'),
                    style: TextStyle(
                      color: widget.lift.referenceLiftId != null ? Colors.redAccent : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )),


            // Totals Row
            TableRow(
              children: [
                // **Label - "Total"**
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Total",
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

                // ✅ Total Reps - DARK GREY
                Container(
                  color: Colors.grey[900],
                  padding: const EdgeInsets.all(8.0),
                  child: Text(getLiftReps(_repsControllers, isDumbbellLift: widget.lift.isDumbbellLift).toString(),
                      style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
                ),

                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),

               // ✅ Total Lift Workload - DARK GREY
                Container(
                  color: Colors.grey[900],
                  padding: const EdgeInsets.all(8.0),
                  child: Text(getLiftWorkload(_repsControllers, _weightControllers, isDumbbellLift: widget.lift.isDumbbellLift).toStringAsFixed(0),
                      style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
                ),
                Container(
                  height: 40, // ✅ Matches row height
                  constraints: BoxConstraints(minWidth: 8, maxWidth: 12), // ✅ Prevents layout errors
                  color: Colors.black, // ✅ Ensures correct grey shade
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _prevTotalReps.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _prevTotalWeight.toStringAsFixed(0),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            // Score Row
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("Score", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                // ✅ Total Lift Score
                Container(
                  color: Colors.blueAccent[700],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      getLiftScore(_repsControllers, _weightControllers, widget.lift.scoreMultiplier, isDumbbellLift: widget.lift.isDumbbellLift, scoreType: widget.lift.scoreType).toString(),
                      style: TextStyle(color: Colors.white, fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Container(
                  height: 40, // ✅ Matches row height
                  constraints: BoxConstraints(minWidth: 8, maxWidth: 12), // ✅ Prevents layout errors
                  color: Colors.black, // ✅ Ensures correct grey shade
                ),

                Padding(padding: const EdgeInsets.all(8.0), child: Text("-", style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center)), // Placeholder for Prev Score
                Padding(padding: const EdgeInsets.all(8.0), child: Text("", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                // ✅ Total Previous Lift Score
                Container(
                  color: Colors.blue[900],
                  child:Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _prevLiftScore.toStringAsFixed(1),
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        const Divider(color: Colors.grey, thickness: 2),
      ],
    );
  }
}

