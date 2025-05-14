import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/db_service.dart';

class ClinkComposer extends StatefulWidget {
  const ClinkComposer({super.key});

  @override
  State<ClinkComposer> createState() => _ClinkComposerState();
}

class _ClinkComposerState extends State<ClinkComposer> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  final int _maxLength = 150;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _prefillClink();
  }

  Future<void> _prefillClink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final info = await getCurrentWorkoutInfo(user.uid);

    if (info != null) {
      final block = info['blockName'];
      final workout = info['workoutName'];
      final week = info['week'];

      setState(() {
        _controller.text = 'Clocking in: W$week $workout, $block';
      });
    } else {
      setState(() {
        _controller.text = "Clocking in 💪";
      });
    }
  }

  Future<Map<String, dynamic>?> getCurrentWorkoutInfo(String userId) async {
    final db = await DBService().database;

    final result = await db.rawQuery('''
    SELECT blockName, workoutName, week
    FROM workout_instances
    WHERE userId = ? AND completed = 0
    ORDER BY startTime DESC
    LIMIT 1
  ''', [userId]);

    if (result.isEmpty) return null;

    final data = result.first;
    return {
      'blockName': data['blockName'] ?? '',
      'workoutName': data['workoutName'] ?? '',
      'week': data['week'] ?? 1,
    };
  }


  Future<void> _submitClink() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > _maxLength) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('timeline_entries')
        .add({
      'userId': user.uid,
      'type': 'clink',
      'clinkSubtype': 'clockin',
      'clink': text,
      'timestamp': Timestamp.now(),
      'displayName': userData['displayName'] ?? 'Lifter',
      'title': userData['title'] ?? '',
      'profileImageUrl': userData['profileImageUrl'] ?? '',
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Drop a Clink',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    minLines: 3,
                    maxLength: _maxLength,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Clocking in 💪',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: const TextStyle(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitClink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Clink'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
