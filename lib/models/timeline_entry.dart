import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineEntry {
  final String entryId;
  final List<String> imageUrls;
  final DateTime timestamp;
  final String userId;
  final String? displayName;
  final String? title;
  final String? profileImageUrl;
  final String type; // 'clink' or 'checkin'
  final String? clinkSubtype; // 'message' or 'clockin'
  final String? clink;
  final String? note; // replaces notes — supports clink messages or check-in notes
  final double? weight;
  final double? bodyFat;
  final double? bmi;
  final String? block;
  final Map<String, dynamic>? reactions;
  final Map<String, List<String>>? reactionUsers;

  TimelineEntry({
    required this.entryId,
    required this.imageUrls,
    required this.timestamp,
    required this.userId,
    this.displayName,
    this.title,
    this.profileImageUrl,
    required this.type,
    this.clinkSubtype,
    this.note,
    this.clink,
    this.weight,
    this.bodyFat,
    this.bmi,
    this.block,
    this.reactions,
    this.reactionUsers,
  });

  factory TimelineEntry.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.fromMillisecondsSinceEpoch(0); // fallback
    }

    return TimelineEntry(
      entryId: id,
      userId: data['userId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      displayName: data['displayName'],
      title: data['title'],
      profileImageUrl: data['profileImageUrl'],
      timestamp: parseTimestamp(data['timestamp']),
      type: data['type'] ?? 'checkin',
      clinkSubtype: data['clinkSubtype'],
      clink: data['clink'],
      note: data['note'],
      weight: data['weight']?.toDouble(),
      bodyFat: data['bodyFat']?.toDouble(),
      bmi: data['bmi']?.toDouble(),
      block: data['block'],
      reactions: data['reactions'] as Map<String, dynamic>? ?? {},
      reactionUsers: (data['reactionUsers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
      ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrls': imageUrls,
      'displayName': displayName,
      'title': title,
      'profileImageUrl': profileImageUrl,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'clinkSubtype': clinkSubtype,
      'clink': clink,
      'note': note,
      'weight': weight,
      'bodyFat': bodyFat,
      'bmi': bmi,
      'block': block,
      'reactions': reactions ?? {},
      'reactionUsers': reactionUsers ?? {},
    };
  }
}
