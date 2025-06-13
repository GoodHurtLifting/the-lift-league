import 'package:flutter/material.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/block_manager_service.dart';

class WorkoutManagerScreen extends StatefulWidget {
  const WorkoutManagerScreen({super.key});

  @override
  State<WorkoutManagerScreen> createState() => _WorkoutManagerScreenState();
}

class _WorkoutManagerScreenState extends State<WorkoutManagerScreen> {
  final DBService _db = DBService();
  final BlockManagerService _manager = BlockManagerService();
  List<Map<String, dynamic>> lifts = [];
  List<Map<String, dynamic>> blocks = [];
  List<Map<String, dynamic>> workouts = [];
  int? selectedBlockId;
  int? selectedWorkoutId;
  bool sortAsc = true;
  bool loading = true;
  bool executing = false;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
    _loadLifts();
  }

  Future<void> _loadLifts() async {
    final all = await _db.getAllLifts();
    setState(() {
      lifts = all;
      loading = false;
    });
    _sortLifts();
  }

  Future<void> _loadBlocks() async {
    final b = await _db.getAllBlocks();
    setState(() => blocks = b);
  }

  Future<void> _loadWorkoutsForBlock(int blockId) async {
    final w = await _db.getWorkoutsByBlockId(blockId);
    setState(() {
      workouts = w;
      selectedWorkoutId = null;
    });
  }

  Future<void> _loadLiftsForWorkout(int workoutId) async {
    setState(() => loading = true);
    final l = await _db.getLiftsByWorkoutId(workoutId);
    setState(() {
      lifts = l;
      loading = false;
    });
    _sortLifts();
  }

  void _sortLifts() {
    lifts.sort((a, b) {
      final nameA = (a['liftName'] ?? '').toString().toLowerCase();
      final nameB = (b['liftName'] ?? '').toString().toLowerCase();
      return sortAsc ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
  }

  void _addLift() {
    setState(() {
      lifts.add({
        'liftId': DateTime.now().millisecondsSinceEpoch,
        'liftName': '',
        'repScheme': '',
        'scoreType': 'multiplier',
        'scoreMultiplier': 0.0,
        'youtubeUrl': '',
        'description': '',
      });
    });
    _sortLifts();
  }

  Future<void> _execute() async {
    setState(() => executing = true);
    try {
      await _manager.executeUpdates(lifts);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Updates applied')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: \\$e')));
    }
    setState(() => executing = false);
  }

  Widget _buildLiftCard(int index) {
    final lift = lifts[index];
    return ExpansionTile(
        title: Text(
            '${lift['liftName'] ?? 'New Lift'} • ${lift['repScheme'] ?? ''}'),
        children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => lift['liftName'] = v,
                controller: TextEditingController(text: lift['liftName'] ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (lift['liftName'] ?? '').length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Rep Scheme'),
                onChanged: (v) => lift['repScheme'] = v,
                controller: TextEditingController(text: lift['repScheme'] ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (lift['repScheme'] ?? '').length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Score Type'),
                onChanged: (v) => lift['scoreType'] = v,
                controller: TextEditingController(text: lift['scoreType'] ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (lift['scoreType'] ?? '').length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Score Multiplier'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                lift['scoreMultiplier'] = double.tryParse(v) ?? 0.0,
                controller: TextEditingController(
                    text: (lift['scoreMultiplier'] ?? 0).toString())
                  ..selection = TextSelection.collapsed(
                      offset:
                      ((lift['scoreMultiplier'] ?? 0).toString()).length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Video URL'),
                onChanged: (v) => lift['youtubeUrl'] = v,
                controller: TextEditingController(text: lift['youtubeUrl'] ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (lift['youtubeUrl'] ?? '').length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
                onChanged: (v) => lift['description'] = v,
                controller: TextEditingController(text: lift['description'] ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (lift['description'] ?? '').length),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: const Text('Block'),
              value: selectedBlockId,
              items: blocks
                  .map((b) => DropdownMenuItem<int>(
                        value: b['blockId'] as int,
                        child: Text(b['blockName'] as String),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedBlockId = v;
                });
                _loadWorkoutsForBlock(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: const Text('Workout'),
              value: selectedWorkoutId,
              items: workouts
                  .map((w) => DropdownMenuItem<int>(
                        value: w['workoutId'] as int,
                        child: Text(w['workoutName'] as String),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  selectedWorkoutId = v;
                });
                _loadLiftsForWorkout(v);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                selectedBlockId = null;
                selectedWorkoutId = null;
                workouts.clear();
              });
              _loadLifts();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Manager'),
        actions: [
          IconButton(
            icon: Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                sortAsc = !sortAsc;
                _sortLifts();
              });
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterRow(),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        itemCount: lifts.length,
                        itemBuilder: (c, i) => _buildLiftCard(i),
                      ),
                      if (executing)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addLift,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'exec',
            onPressed: executing ? null : _execute,
            label: const Text('Execute'),
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}