// lib/widgets/big_three_prs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BigThreePRs extends StatelessWidget {
  final String userId;

  const BigThreePRs({super.key, required this.userId});

  Future<Map<String, double>> _fetchPRs() async {
    final prs = <String, double>{};
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('big3_prs')
        .get();

    for (var doc in snapshot.docs) {
      final liftName = doc.id;
      final bestWeight = (doc.data()['bestWeight'] ?? 0).toDouble();
      prs[liftName] = bestWeight;
    }

    return prs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: _fetchPRs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prs = snapshot.data!;
        if (prs.isEmpty) {
          return const Text('No PRs logged for the Big Three yet.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Big Three PRs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...['Bench Press', 'Squats', 'Deadlift'].map((lift) {
              final weight = prs[lift] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lift, style: const TextStyle(fontSize: 16)),
                    Text('${weight.toStringAsFixed(0)} lbs',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
