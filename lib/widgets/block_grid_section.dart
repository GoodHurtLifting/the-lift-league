import 'dart:io';

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
  final List<int>? customBlockIds;
  final void Function(int id)? onDeleteCustomBlock;
  final void Function(int id)? onEditCustomBlock;
  final bool overlayNames;

  const BlockGridSection({
    super.key,
    required this.workoutImages,
    required this.blockNames,
    required this.blockInstances,
    required this.isLoading,
    required this.onNewBlockInstanceCreated,
    this.customBlockIds,
    this.onDeleteCustomBlock,
    this.onEditCustomBlock,
    this.overlayNames = false,
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
          onLongPress:
              customBlockIds != null && (onDeleteCustomBlock != null || onEditCustomBlock != null)
                  ? () async {
                      final id = customBlockIds![index];
                      final action = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEditCustomBlock != null)
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit'),
                                  onTap: () => Navigator.pop(ctx, 'edit'),
                                ),
                              if (onDeleteCustomBlock != null)
                                ListTile(
                                  leading: const Icon(Icons.delete),
                                  title: const Text('Delete'),
                                  onTap: () => Navigator.pop(ctx, 'delete'),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (action == 'edit' && onEditCustomBlock != null) {
                        onEditCustomBlock!(id);
                      } else if (action == 'delete' && onDeleteCustomBlock != null) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete block?'),
                            content: const Text('Are you sure you want to delete this block?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          onDeleteCustomBlock!(id);
                        }
                      }
                    }
                  : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: overlayNames
                    ? Opacity(
                        opacity: 0.5,
                        child: workoutImages[index].startsWith('assets/')
                            ? Image.asset(workoutImages[index], fit: BoxFit.cover)
                            : Image.file(File(workoutImages[index]), fit: BoxFit.cover),
                      )
                    : workoutImages[index].startsWith('assets/')
                        ? Image.asset(workoutImages[index], fit: BoxFit.cover)
                        : Image.file(File(workoutImages[index]), fit: BoxFit.cover),
              ),
              if (overlayNames)
                Center(
                  child: Text(
                    blockName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
