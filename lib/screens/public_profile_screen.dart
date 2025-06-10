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
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = doc.data();
    if (data == null) return;

    final blockName = data['activeBlockName'];
    if (blockName != null) {
      bannerImagePath =
          blockBannerImages[blockName] ?? 'assets/images/PushPullLegs.jpg';
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
                            : const AssetImage(
                                'assets/images/PushPullLegs.jpg'),
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
                            backgroundImage: (profileUrl != null &&
                                    profileUrl!.isNotEmpty)
                                ? NetworkImage(profileUrl!)
                                : const AssetImage('assets/images/flatLogo.jpg')
                                    as ImageProvider,
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
            FutureBuilder<List<bool>>(
              future: _getFollowAndCircleStatus(
                FirebaseAuth.instance.currentUser!.uid,
                widget.userId,
              ),
              builder: (context, snapshot) {
                final isFollowing = snapshot.data?[0] ?? false;
                final isInCircle = snapshot.data?[1] ?? false;
                final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconRectButton(
                      icon: Icons.bar_chart,
                      onPressed: showStats
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserStatsScreen(
                                    userId: widget.userId,
                                    showCheckInGraph: false,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    if (widget.userId != currentUserId) ...[
                      const SizedBox(width: 16),
                      _iconRectButton(
                        icon: isFollowing
                            ? Icons.person_remove
                            : Icons.person_add,
                        onPressed: () async {
                          if (isFollowing) {
                            await UserFollowService()
                                .unfollowUser(currentUserId, widget.userId);
                            _showActionLabel('Unfollowed');
                          } else {
                            await UserFollowService()
                                .followUser(currentUserId, widget.userId);
                            _showActionLabel('Followed');
                          }
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 16),
                      _iconRectButton(
                        icon: isInCircle
                            ? Icons.remove_circle_outline
                            : Icons.control_point,
                        onPressed: isFollowing
                            ? () async {
                                if (isInCircle) {
                                  await UserFollowService()
                                      .removeFromTrainingCircle(
                                          currentUserId, widget.userId);
                                  _showActionLabel('Removed');
                                } else {
                                  final doc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userId)
                                      .get();
                                  final data = doc.data();
                                  if (data == null) return;
                                  await UserFollowService()
                                      .addToTrainingCircle(currentUserId, {
                                    'userId': widget.userId,
                                    'displayName': data['displayName'],
                                    'profileImageUrl': data['profileImageUrl'],
                                    'title': data['title'],
                                  });
                                  _showActionLabel('Added to Circle');
                                }
                                setState(() {});
                              }
                            : null,
                      ),
                    ],
                    const SizedBox(width: 16),
                    _iconRectButton(
                      icon: Icons.message,
                      onPressed: isInCircle
                          ? () async {
                              final chatId = await getOrCreateChat(
                                  currentUserId, widget.userId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ChatScreen(chatId: chatId)),
                              );
                            }
                          : null,
                    ),
                  ],
                );
              },
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

  Future<List<bool>> _getFollowAndCircleStatus(
      String currentUserId, String targetUserId) async {
    final followService = UserFollowService();
    final isFollowing =
        await followService.isFollowing(currentUserId, targetUserId);
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

  Widget _iconRectButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: SizedBox(
        width: 80,
        height: 40,
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
