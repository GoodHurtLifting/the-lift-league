import 'package:flutter/material.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/services/block_manager_service.dart';
import 'package:lift_league/data/block_data.dart';
import 'package:lift_league/utils/workout_utils.dart';

class BlockManagerScreen extends StatefulWidget {
  const BlockManagerScreen({super.key});

  @override
  State<BlockManagerScreen> createState() => _BlockManagerScreenState();
}

class _BlockManagerScreenState extends State<BlockManagerScreen> {
  final DBService _db = DBService();
  final BlockManagerService _manager = BlockManagerService();
  List<Map<String, dynamic>> lifts = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedLifts = {};
  bool loading = true;
  bool executing = false;

  @override
  void initState() {
    super.initState();
    _loadGroupedLifts();
  }

  Future<void> _loadGroupedLifts() async {
    final data = await _db.getLiftsByBlockAndWorkout();
    final Map<String, Map<String, List<Map<String, dynamic>>>> temp = {};
    final Map<String, int> blockIds = {};
    final List<Map<String, dynamic>> all = [];

    for (final row in data) {
      final blockName = (row['blockName'] ?? '') as String;
      final workoutName = (row['workoutName'] ?? '') as String;
      final lift = {
        'liftId': row['liftId'],
        'liftName': row['liftName'],
        'repScheme': row['repScheme'],
        'scoreType': row['scoreType'],
        'scoreMultiplier': row['scoreMultiplier'],
        'youtubeUrl': row['youtubeUrl'],
        'description': row['description'],
      };

      all.add(lift);
      blockIds[blockName] = row['blockId'] as int;
      temp.putIfAbsent(blockName, () => {});
      temp[blockName]!.putIfAbsent(workoutName, () => []);
      temp[blockName]![workoutName]!.add(lift);
    }

    final Map<String, Map<String, List<Map<String, dynamic>>>> ordered = {};
    final List<String> blockOrder =
        blockDataList.map((b) => b['blockName'] as String).toList();

    for (final name in blockOrder) {
      if (!temp.containsKey(name)) continue;
      final workouts = temp[name]!;
      final int? id = blockIds[name];
      final List<String> workoutOrder =
          id != null ? getOrderedWorkoutNamesForBlock(id) : workouts.keys.toList();

      final Map<String, List<Map<String, dynamic>>> wMap = {};
      for (final w in workoutOrder) {
        if (workouts.containsKey(w)) {
          wMap[w] = workouts[w]!;
        }
      }
      for (final entry in workouts.entries) {
        wMap.putIfAbsent(entry.key, () => entry.value);
      }
      ordered[name] = wMap;
    }

    // Append any blocks not specified in blockOrder
    for (final entry in temp.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }

    setState(() {
      groupedLifts = ordered;
      lifts = all;
      loading = false;
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

  Widget _buildLiftCard(Map<String, dynamic> lift) {
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

  Widget _buildGroupedList() {
    final List<Widget> items = [];
    groupedLifts.forEach((blockName, workouts) {
      items.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.grey.shade300,
        child: Text(
          blockName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ));
      workouts.forEach((workoutName, lifts) {
        items.add(
          ExpansionTile(
            title: Text(workoutName),
            children: lifts.map(_buildLiftCard).toList(),
          ),
        );
      });
    });

    return ListView(children: items);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Manager'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildGroupedList(),
                if (executing)
                  const Center(child: CircularProgressIndicator()),
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