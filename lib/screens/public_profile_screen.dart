import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/widgets/timeline_public.dart';
import 'user_stats_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:lift_league/services/user_follow_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? bannerImagePath;
  String? _actionLabel;

  final Map<String, String> blockBannerImages = {
    "Push Pull Legs": 'assets/images/PushPullLegs.jpg',
    "Upper Lower": 'assets/images/UpperLower.jpg',
    "Full Body": 'assets/images/FullBody.jpg',
    "Full Body Plus": 'assets/images/FullBodyPlus.jpg',
    "5 X 5": 'assets/images/5x5.jpg',
    "Texas Method": 'assets/images/TexasMethod.jpg',
    "Wuehr Hammer": 'assets/images/WuehrHammer.jpg',
    "Gran Moreno": 'assets/images/GranMoreno.jpg',
    "Body Split": 'assets/images/BodySplit.jpg',
    "Shatner": 'assets/images/Shatner.jpg',
    "Super Split": 'assets/images/SuperSplit.jpg',
    "PPL Plus": 'assets/images/PushPullLegsPlus.jpg',
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _showActionLabel(String message) {
    setState(() => _actionLabel = message);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _actionLabel = null);
    });
  }

  Future<void> _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    final data = doc.data();
    if (data == null) return;

    final blockName = data['activeBlockName'];
    if (blockName != null) {
      bannerImagePath = blockBannerImages[blockName] ?? 'assets/images/PushPullLegs.jpg';
    }

    setState(() {
      userData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      return const Scaffold(
        body: Center(child: Text('User not found.')),
      );
    }

    final profileUrl = userData!['profileImageUrl'];
    final showStats = userData!['showStats'] ?? true;
    final showTimeline = userData!['showTimeline'] ?? true;
    final showCheckInInfo = userData!['showCheckInInfo'] ?? true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _actionLabel != null
            ? Text(
          _actionLabel!,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        )
            : const SizedBox.shrink(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: bannerImagePath != null
                            ? AssetImage(bannerImagePath!)
                            : const AssetImage('assets/images/PushPullLegs.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: 16,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: (profileUrl != null && profileUrl!.isNotEmpty)
                                ? NetworkImage(profileUrl!)
                                : const AssetImage('assets/images/flatLogo.jpg') as ImageProvider,
                          ),
                        ),
                        if (widget.userId != FirebaseAuth.instance.currentUser?.uid)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: FutureBuilder<List<bool>>(
                              future: _getFollowAndCircleStatus(
                                FirebaseAuth.instance.currentUser!.uid,
                                widget.userId,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox();

                                final isFollowing = snapshot.data![0];
                                final isInCircle = snapshot.data![1];
                                final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                                if (!isFollowing) {
                                  return _smallActionButton(
                                    icon: Icons.person_add,
                                    color: Colors.blueAccent,
                                    onTap: () async {
                                      await UserFollowService().followUser(currentUserId, widget.userId);
                                      setState(() {});
                                      _showActionLabel('Followed');
                                    },
                                  );
                                } else if (!isInCircle) {
                                  return _smallActionButton(
                                    icon: Icons.group_add,
                                    color: Colors.green,
                                    onTap: () async {
                                      final doc = await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.userId)
                                          .get();
                                      final userData = doc.data();
                                      if (userData == null) return;

                                      await UserFollowService().addToTrainingCircle(currentUserId, {
                                        'userId': widget.userId,
                                        'displayName': userData['displayName'],
                                        'profileImageUrl': userData['profileImageUrl'],
                                        'title': userData['title'],
                                      });
                                      setState(() {});
                                      _showActionLabel('Added to Circle');
                                    },
                                  );
                                } else {
                                  return _smallActionButton(
                                    icon: Icons.remove_circle_outline,
                                    color: Colors.grey,
                                    onTap: () async {
                                      await UserFollowService()
                                          .removeFromTrainingCircle(currentUserId, widget.userId);
                                      setState(() {});
                                      _showActionLabel('Removed');
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                        Positioned(
                          left: 112,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData!['displayName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFC3B3D),
                                ),
                              ),
                              Text(
                                userData!['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 55),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: showStats
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserStatsScreen(userId: widget.userId),
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text("Stats"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white70,
                    disabledBackgroundColor: Colors.grey,
                    disabledForegroundColor: Colors.white70,
                  ),
                ),
                const SizedBox(width: 16),
                FutureBuilder<List<bool>>(
                  future: _getFollowAndCircleStatus(
                    FirebaseAuth.instance.currentUser!.uid,
                    widget.userId,
                  ),
                  builder: (context, snapshot) {
                    final isInCircle = snapshot.hasData ? snapshot.data![1] : false;

                    return ElevatedButton.icon(
                      onPressed: isInCircle
                          ? () async {
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        final otherUserId = widget.userId;
                        final chatId = await getOrCreateChat(currentUserId!, otherUserId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
                        );
                      }
                          : null,
                      icon: const Icon(Icons.message),
                      label: const Text("Message"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white70,
                        disabledBackgroundColor: Colors.grey,
                        disabledForegroundColor: Colors.white54,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (showTimeline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: .2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimelinePublic(
                      userId: widget.userId,
                      checkInInfo: showCheckInInfo,
                    ),
                  ],
                ),
              )
            else
              const Text("\ud83d\udeab This user's timeline is private."),
          ],
        ),
      ),
    );
  }

  Future<List<bool>> _getFollowAndCircleStatus(String currentUserId, String targetUserId) async {
    final followService = UserFollowService();
    final isFollowing = await followService.isFollowing(currentUserId, targetUserId);
    final isInCircle = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .doc(targetUserId)
        .get()
        .then((doc) => doc.exists);
    return [isFollowing, isInCircle];
  }

  Future<String> getOrCreateChat(String userId1, String userId2) async {
    final chatId = userId1.hashCode <= userId2.hashCode
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final doc = await chatRef.get();

    if (!doc.exists) {
      await chatRef.set({
        'chatId': chatId,
        'members': [userId1, userId2],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'blockedBy': null,
      });
    }
    return chatId;
  }

  Widget _smallActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}