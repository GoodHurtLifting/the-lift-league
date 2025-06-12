import 'package:flutter/material.dart';
import 'package:lift_league/models/timeline_entry.dart';
import 'full_screen_photo_viewer.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/reaction_bar.dart';

class TimelineCheckinCard extends StatelessWidget {
  final TimelineEntry entry;
  final String entryId;
  final String userId;
  final bool readonly;
  final String? displayName;
  final String? title;
  final String? profileImageUrl;
  final bool showProfileInfo;
  final bool showCheckInInfo;
  final VoidCallback? onTapProfile;
  final VoidCallback? onLikeAdded;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final bool showBottomBorder;

  const TimelineCheckinCard({
    super.key,
    required this.entry,
    required this.entryId,
    required this.userId,
    this.displayName,
    this.title,
    this.profileImageUrl,
    this.showProfileInfo = false,
    this.readonly = false,
    this.showCheckInInfo = true,
    this.onTapProfile,
    this.onLikeAdded,
    this.backgroundColor = Colors.black,
    this.borderRadius,
    this.showBottomBorder = true,
  });

  Widget _buildImageRow(BuildContext context, List<String> imageUrls) {
    final int count = imageUrls.length;
    final double spacing = 6;

    return Row(
      mainAxisAlignment: count == 1
          ? MainAxisAlignment.center
          : count == 2
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.spaceBetween,
      children: imageUrls.map((url) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenPhotoViewer(imageUrl: url),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
    DateFormat('MM/dd/yyyy').format(entry.timestamp.toLocal());
    final isOwner = userId == FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onTap: onTapProfile,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: showBottomBorder
              ? Border(
            bottom: BorderSide(color: Colors.grey.shade700, width: 0.5),
          )
              : null,
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
                      backgroundImage: profileImageUrl != null &&
                          profileImageUrl!.isNotEmpty
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/images/flatLogo.jpg')
                      as ImageProvider,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName ?? 'Lifter',
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                        if (title != null && title!.isNotEmpty)
                          Text(
                            title!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (showProfileInfo) const SizedBox(height: 8),
            _buildImageRow(context, entry.imageUrls),
            const SizedBox(height: 8),
            // ⬇️ Check-in info & ReactionBar aligned horizontally
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showCheckInInfo && entry.weight != null)
                        Text("Weight: ${entry.weight} lbs",
                            style: const TextStyle(fontSize: 10)),
                      if (showCheckInInfo && entry.bodyFat != null)
                        Text("Body Fat: ${entry.bodyFat}%",
                            style: const TextStyle(fontSize: 10)),
                      if (showCheckInInfo && entry.bmi != null)
                        Text("BMI: ${entry.bmi}",
                            style: const TextStyle(fontSize: 10)),
                      if (showCheckInInfo && entry.block != null)
                        Text("Block: ${entry.block}",
                            style: const TextStyle(fontSize: 10)),
                      if (showCheckInInfo && entry.note?.isNotEmpty == true)
                        Text("${entry.note}",
                            style: const TextStyle(fontSize: 10)),
                      Text("Date: $formattedDate",
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 8),
                  ReactionBar(
                    userId: userId,
                    entryId: entryId,
                    isOwner: isOwner,
                    reactions: entry.reactions ?? {},
                    reactionUsers: entry.reactionUsers ?? {},
                    onLikeAdded: onLikeAdded,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
