import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class TimelineClinkCard extends StatelessWidget {
  final String? clink;
  final DateTime timestamp;
  final String? displayName;
  final String? title;
  final String? profileImageUrl;
  final bool showProfileInfo;
  final VoidCallback? onTapProfile;

  const TimelineClinkCard({
    super.key,
    required this.clink,
    required this.timestamp,
    this.displayName,
    this.title,
    this.profileImageUrl,
    this.showProfileInfo = false,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMM d, yyyy – h:mm a').format(timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showProfileInfo)
              InkWell(
                onTap: onTapProfile,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName ?? 'Lifter',
                            style: const TextStyle(
                                color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        if (title != null && title!.isNotEmpty)
                          Text(title!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            if (showProfileInfo) const SizedBox(height: 8),
            const SizedBox(height: 8),
            Text(clink!, style: const TextStyle(color: Colors.white)),
            Text(formatted, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
