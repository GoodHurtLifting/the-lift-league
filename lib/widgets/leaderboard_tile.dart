import 'package:flutter/material.dart';
import 'package:lift_league/screens/public_profile_screen.dart';

class LeaderboardTile extends StatelessWidget {
  final String displayName;
  final String profileImageUrl;
  final String blockScore;
  final List<String> workoutScores;
  final String title;
  final String userId;

  const LeaderboardTile({
    super.key,
    required this.userId,
    required this.displayName,
    required this.profileImageUrl,
    required this.blockScore,
    required this.workoutScores,
    required this.title,
  });

  bool isValidProfileUrl(String? url) {
    return url != null && url.startsWith('http') && url.length > 30;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: userId),
          ),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[300],
          backgroundImage: isValidProfileUrl(profileImageUrl)
              ? NetworkImage(profileImageUrl)
              : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFC3B3D)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontStyle: FontStyle.italic, height: 1.3),
            ),
            Text(
              'Block Score: $blockScore',
              style: const TextStyle(height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(workoutScores.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'WO${index + 1}: ${workoutScores[index]}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
