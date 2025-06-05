import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReactionBar extends StatefulWidget {
  final String userId;
  final String entryId;
  final bool isOwner;
  final Map<String, dynamic> reactions;
  final Map<String, List<String>> reactionUsers; // ✅ NEW
  final VoidCallback? onLikeAdded;


  const ReactionBar({
    super.key,
    required this.userId,
    required this.entryId,
    required this.isOwner,
    required this.reactions,
    required this.reactionUsers,
    this.onLikeAdded,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late final String currentUserId;
  late Map<String, List<String>> userReactionMap;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ✅ Initialize with cached data from TimelineEntry
    userReactionMap = {
      "flex": List<String>.from(widget.reactionUsers["flex"] ?? []),
    };
  }

  Future<void> _loadReactions() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .doc(widget.entryId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final Map<String, dynamic> raw = Map<String, dynamic>.from(data['reactionUsers'] ?? {});
    setState(() {
      userReactionMap = {
        "flex": List<String>.from(raw["flex"] ?? []),
      };
    });
  }

  Future<void> _toggleReaction(String type) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .doc(widget.entryId);

    final currentUsers = List<String>.from(userReactionMap[type] ?? []);
    final hasReacted = currentUsers.contains(currentUserId);

    if (hasReacted) {
      currentUsers.remove(currentUserId);
    } else {
      currentUsers.add(currentUserId);
      // Increment hype counter when a new like is added
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'likesGiven': FieldValue.increment(1)});
      widget.onLikeAdded?.call();
    }

    setState(() {
      userReactionMap[type] = currentUsers;
    });

    await docRef.set({
      'reactionUsers': {
        type: currentUsers,
      }
    }, SetOptions(merge: true));
  }

  int _reactionCount(String type) {
    return userReactionMap[type]?.length ?? 0;
  }

  bool _hasReacted(String type) {
    return userReactionMap[type]?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AnimatedReactionIcon(
          icon: Icons.fitness_center,
          color: Colors.green,
          onTap: () => _toggleReaction("flex"),
          count: widget.isOwner ? _reactionCount("flex") : null,
          active: _hasReacted("flex"),
        ),
      ],
    );
  }
}

class _AnimatedReactionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? count;
  final bool active;

  const _AnimatedReactionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
    this.active = false,
  });

  @override
  State<_AnimatedReactionIcon> createState() => _AnimatedReactionIconState();
}

class _AnimatedReactionIconState extends State<_AnimatedReactionIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      ),
      child: Column(
        children: [
          IconButton(
            icon: Icon(
              widget.icon,
              color: widget.active ? widget.color : Colors.grey[600],
            ),
            onPressed: _handleTap,
          ),
          if (widget.count != null)
            Text('${widget.count}', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
