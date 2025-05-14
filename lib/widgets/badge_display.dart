import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeDisplay extends StatelessWidget {
  final String userId;

  const BadgeDisplay({super.key, required this.userId});

  Future<List<Map<String, dynamic>>> _fetchBadges() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('badges')
        .orderBy('unlockDate', descending: true)
        .get();

    final badgeCounts = <String, Map<String, dynamic>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Unnamed Badge';
      if (badgeCounts.containsKey(name)) {
        badgeCounts[name]!['count'] += 1;
      } else {
        badgeCounts[name] = {
          ...data,
          'count': 1,
        };
      }
    }

    return badgeCounts.values.toList();
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBadges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final badges = snapshot.data!;
        if (badges.isEmpty) {
          return const Text('No badges earned yet.', style: TextStyle(color: Colors.white));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Badges',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                final String imagePath = badge['imagePath'] ?? 'assets/images/badges/meatWagon_01.png';
                final String title = badge['name'] ?? '';
                final String description = badge['description'] ?? '';
                final int count = badge['count'] ?? 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🖼️ Clickable Badge Image
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    imagePath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 64),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          decoration: TextDecoration.none,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            imagePath,
                            height: 100,
                            fit: BoxFit.fitHeight,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.error, size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 🏷️ Badge title and count inline
                      Expanded(
                        child: Text(
                          '$title  x$count',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),


                );
              },
            ),
          ],
        );
      },
    );
  }
}
