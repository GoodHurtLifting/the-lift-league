import 'package:flutter/material.dart';
import 'package:lift_league/screens/public_profile_screen.dart';

class BadgeBoardTile extends StatelessWidget {
  final String userId;
  final String displayName;
  final String profileImageUrl;
  final String title;
  final int badgeCount;

  const BadgeBoardTile({
    super.key,
    required this.userId,
    required this.displayName,
    required this.profileImageUrl,
    required this.title,
    required this.badgeCount,
  });

  bool _validUrl(String? url) {
    return url != null && url.startsWith('http') && url.length > 30;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[300],
          backgroundImage: _validUrl(profileImageUrl)
              ? NetworkImage(profileImageUrl)
              : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Color(0xFFFC3B3D),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          title,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        trailing: Text(
          'Badges: $badgeCount',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
