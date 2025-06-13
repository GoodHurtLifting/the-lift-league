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
  bool loading = true;
  bool executing = false;

  @override
  void initState() {
    super.initState();
    _loadLifts();
  }

  Future<void> _loadLifts() async {
    final all = await _db.getAllLifts();
    setState(() {
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

  Widget _buildLiftCard(int index) {
    final lift = lifts[index];
    return ExpansionTile(
      title: Text(lift['liftName'] ?? 'New Lift'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Manager')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          ListView.builder(
            itemCount: lifts.length,
            itemBuilder: (c, i) => _buildLiftCard(i),
          ),
          if (executing) const Center(child: CircularProgressIndicator()),
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