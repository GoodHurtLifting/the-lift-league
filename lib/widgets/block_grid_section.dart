import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/screens/block_dashboard.dart';

class BlockGridSection extends StatelessWidget {
  final List<String> workoutImages;
  final List<String> blockNames;
  final Map<String, int?> blockInstances;
  final bool isLoading;
  final Function(String, int) onNewBlockInstanceCreated;

  const BlockGridSection({
    super.key,
    required this.workoutImages,
    required this.blockNames,
    required this.blockInstances,
    required this.isLoading,
    required this.onNewBlockInstanceCreated,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: workoutImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        String blockName = blockNames[index];
        int? blockInstanceId = blockInstances[blockName];

        return GestureDetector(
          onTap: () async {
            final db = DBService();
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;

            if (blockInstanceId == null) {
              int newId = await db.insertNewBlockInstance(blockName, user.uid);
              onNewBlockInstanceCreated(blockName, newId);
              blockInstanceId = newId;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlockDashboard(blockInstanceId: blockInstanceId!),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(workoutImages[index]),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}
