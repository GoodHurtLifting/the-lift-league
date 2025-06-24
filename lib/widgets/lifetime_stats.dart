import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LifetimeStats extends StatelessWidget {
  final String userId;

  const LifetimeStats({super.key, required this.userId});

  Future<Map<String, dynamic>> _fetchStats() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data() ?? {};

    return {
      'totalLbsLifted': (data['totalLbsLifted'] ?? 0).toDouble(),
      'blocksCompleted': (data['blocksCompleted'] ?? 0),
      'workoutsCompleted': (data['workoutsCompleted'] ?? 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildStatRow('Total Workload', '${stats['totalLbsLifted'].toStringAsFixed(0)} lbs'),
            _buildStatRow('Blocks Completed', '${stats['blocksCompleted']}'),
            _buildStatRow('Workouts Completed', '${stats['workoutsCompleted']}'),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
