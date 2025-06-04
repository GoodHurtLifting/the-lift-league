import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class TimelineClinkCard extends StatelessWidget {
  final String? clink;
  final DateTime timestamp;
  final String? displayName;
  final String? title;
  final String? profileImageUrl;
  final List<String> imageUrls;
  final bool showProfileInfo;
  final VoidCallback? onTapProfile;

  const TimelineClinkCard({
    super.key,
    required this.clink,
    required this.timestamp,
    this.displayName,
    this.title,
    this.profileImageUrl,
    this.imageUrls = const [],
    this.showProfileInfo = false,
    this.onTapProfile,
  });

  Widget _buildImageRow(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final double spacing = 6;
    return Row(
      mainAxisAlignment: urls.length == 1
          ? MainAxisAlignment.center
          : urls.length == 2
          ? MainAxisAlignment.spaceEvenly
          : MainAxisAlignment.spaceBetween,
      children: urls.map((url) {
        final isAsset = url.startsWith('assets/');
        final image = isAsset ? Image.asset(url) : Image.network(url);
        return Flexible(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: image,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMM d, yyyy – h:mm a').format(timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 0.5),
        ),
      ),
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
            if (imageUrls.isNotEmpty) ...[
              _buildImageRow(imageUrls),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(clink!, style: const TextStyle(color: Colors.white)),
            Text(formatted, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],

      ),
    );
  }
}
