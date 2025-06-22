import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/models/timeline_entry.dart';
import 'package:lift_league/widgets/timeline_checkin_card.dart';
import 'package:lift_league/screens/edit_check_in_screen.dart';
import 'package:lift_league/widgets/timeline_clink_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show NetworkAssetBundle;

class DismissibleTimelineItem extends StatelessWidget {
  final String userId;
  final TimelineEntry entry;
  final VoidCallback refresh;

  const DismissibleTimelineItem({
    super.key,
    required this.userId,
    required this.entry,
    required this.refresh,
  });

  Future<void> _handleShare(BuildContext context) async {
    String shareText;
    if (entry.type == 'checkin') {
      final buffer = StringBuffer();
      buffer.writeln(
          'Check-In: ${entry.timestamp.toLocal().toString().split(' ').first}');
      if (entry.block != null) buffer.writeln('Block: ${entry.block}');
      if (entry.weight != null) buffer.writeln('Weight: ${entry.weight} lbs');
      if (entry.bodyFat != null) buffer.writeln('Body Fat: ${entry.bodyFat}%');
      if (entry.bmi != null) buffer.writeln('BMI: ${entry.bmi}');
      buffer.writeln('\n#TheLiftLeague');
      shareText = buffer.toString();
    } else {
      shareText = '${entry.clink ?? ''}\n\n#TheLiftLeague';
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final List<XFile> imageFiles = [];

      for (int i = 0; i < entry.imageUrls.length && i < 3; i++) {
        final url = entry.imageUrls[i];
        final response = await NetworkAssetBundle(Uri.parse(url)).load('');
        final originalBytes = response.buffer.asUint8List();

        final originalImage = img.decodeImage(originalBytes);
        if (originalImage == null) continue;

        final logoBytes = await rootBundle.load('assets/images/rebrand_LL_pink_S.png');
        final logoImage = img.decodeImage(logoBytes.buffer.asUint8List());
        if (logoImage == null) continue;

        final resizedLogo = img.copyResize(logoImage, width: 150);
        img.compositeImage(originalImage, resizedLogo, dstX: 50, dstY: 50);

        final watermarkedBytes = img.encodeJpg(originalImage);
        final file = await File('${tempDir.path}/shared_${entry.type}_$i.jpg').create();
        await file.writeAsBytes(watermarkedBytes);

        imageFiles.add(XFile(file.path));
      }

      await Clipboard.setData(ClipboardData(text: shareText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption copied to clipboard')),
      );

      if (imageFiles.isNotEmpty) {
        await Share.shareXFiles(imageFiles, text: shareText);
      } else {
        Share.share(shareText);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share images: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryId = entry.entryId;

    return Dismissible(
      key: Key(entryId),
      background: Container(
        alignment: Alignment.centerLeft,
        color: Colors.green,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.share, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Delete ${entry.type == 'checkin' ? 'Check-In' : 'Clink'}?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
              ],
            ),
          );
        } else if (direction == DismissDirection.startToEnd) {
          await _handleShare(context);
          return false;
        }
        return false;
      },
      onDismissed: (_) async {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('timeline_entries')
            .doc(entryId)
            .delete();
        refresh();
      },
      child: GestureDetector(
        onTap: () {
          if (entry.type == 'checkin') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditCheckInScreen(entry: entry, entryId: entryId, userId: userId),
              ),
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: entry.type == 'checkin'
            ? TimelineCheckinCard(
          entry: entry,
          entryId: entry.entryId,
          userId: entry.userId,
          readonly: true,
          showCheckInInfo: true,
        )
            : TimelineClinkCard(
          clink: entry.clink ?? '',
          timestamp: entry.timestamp,
          displayName: null,
          title: null,
          profileImageUrl: null,
          imageUrls: entry.imageUrls,
          showProfileInfo: false,
        ),
      ),
    );
  }
}
