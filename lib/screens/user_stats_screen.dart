import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/widgets/lifetime_stats.dart';
import 'package:lift_league/widgets/badge_display.dart';
import 'package:lift_league/widgets/big_three_prs.dart';
import 'package:lift_league/widgets/checkin_graph.dart';
import 'package:lift_league/widgets/consistency_meter.dart';
import 'package:lift_league/widgets/efficiency_meter.dart';
import 'package:lift_league/widgets/momentum_meter.dart';

class UserStatsScreen extends StatelessWidget {
  final String userId;
  final String? blockId;
  final bool showCheckInGraph;

  const UserStatsScreen({
    super.key,
    required this.userId,
    this.blockId,
    this.showCheckInGraph = true,
  });

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    final activeBlockId = blockId;
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          final displayName = userData['displayName'] ?? 'Unknown User';
          final title = userData['title'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇 New section with name + title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFC3B3D),
                      ),
                    ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),

                // Existing sections
                LifetimeStats(userId: userId),
                const SizedBox(height: 20),
                if (activeBlockId == null) ...[
                  const Text('Start a training block to track your stats!'),
                  const SizedBox(height: 20),
                ] else ...[
                  const Text(
                    'Consistency',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ConsistencyMeter(userId: userId,
                    blockId: int.tryParse(activeBlockId) ?? 0,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Efficiency',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  EfficiencyMeter(userId: userId, blockId: activeBlockId),
                  const SizedBox(height: 20),
                  const Text(
                    'Momentum',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  MomentumMeter(userId: userId),
                  const SizedBox(height: 20),
                ],
                if (showCheckInGraph) ...[
                  CheckInGraph(userId: userId),
                  const SizedBox(height: 20),
                ],
                BigThreePRs(userId: userId),
                const SizedBox(height: 20),
                BadgeDisplay(userId: userId),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
