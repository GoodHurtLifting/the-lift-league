import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/widgets/timeline_public.dart';
import 'user_stats_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'following_screen.dart';
import 'training_circle_members_screen.dart';
import 'package:lift_league/services/user_follow_service.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:lift_league/widgets/public_custom_block_grid.dart';

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
  List<Map<String, dynamic>> _publicBlocks = [];
  List<String> _publicBlockImages = [];
  List<String> _publicBlockNames = [];
  bool _showBeforeAfter = false;
  bool _hasEnoughForBA = false;

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

    await _fetchPublicBlocks();
    await _checkBeforeAfterAvailability();
  }

  Future<void> _fetchPublicBlocks() async {
    final snap = await FirebaseFirestore.instance
        .collection('custom_blocks')
        .where('ownerId', isEqualTo: widget.userId)
        .where('isDraft', isEqualTo: false)
        .get();
    setState(() {
      _publicBlocks = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      _publicBlockNames =
          _publicBlocks.map((b) => b['name']?.toString() ?? '').toList();
      _publicBlockImages = _publicBlocks
          .map((b) => b['coverImageUrl']?.toString() ?? 'assets/logo25.jpg')
          .toList();
    });
  }

  Future<void> _checkBeforeAfterAvailability() async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('timeline_entries')
        .where('type', isEqualTo: 'checkin');

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (widget.userId != currentUserId) {
      query = query.where('public', isEqualTo: true);
    }

    final snap = await query.get();
    final count = snap.docs.where((d) {
      final data = d.data();
      final urls = data['imageUrls'];
      return urls is List && urls.isNotEmpty;
    }).length;
    if (mounted) {
      setState(() => _hasEnoughForBA = count >= 3);
    }
  }

  Future<void> _addPublicBlock(int index) async {
    if (index < 0 || index >= _publicBlocks.length) return;
    final data = _publicBlocks[index];
    final block = CustomBlock.fromMap(data);
    await DBService().insertCustomBlock(block);

    final user = FirebaseAuth.instance.currentUser;
    final blockId = data['id']?.toString();
    if (user != null && blockId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('customBlockRefs')
          .doc(blockId)
          .set({'addedAt': FieldValue.serverTimestamp()});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Block added to your custom blocks')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('User not found.')),
      );
    }

    final profileUrl = userData!['profileImageUrl'];
    final showStats = userData!['showStats'] ?? true;
    final showTimeline = userData!['showTimeline'] ?? true;
    final showCheckInInfo = userData!['showCheckInInfo'] ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
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
                            border: Border.all(color: Colors.white, width: 1),
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
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('following')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, followSnap) {
                final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('training_circle')
                      .doc(widget.userId)
                      .snapshots(),
                  builder: (context, circleSnap) {
                    final isFollowing = followSnap.data?.exists ?? false;
                    final isInCircle = circleSnap.data?.exists ?? false;
                    int followStep;
                    if (!isFollowing) {
                      followStep = 0;
                    } else if (isInCircle) {
                      followStep = 2;
                    } else {
                      followStep = 1;
                    }
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
                        if (widget.userId == currentUserId) ...[
                          const SizedBox(width: 16),
                          _iconRectButton(
                            icon: Icons.group,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const FollowingScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          _iconRectButton(
                            icon: Icons.circle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TrainingCircleMembersScreen()),
                              );
                            },
                          ),
                        ],
                        if (widget.userId != currentUserId) ...[
                          const SizedBox(width: 16),
                          _iconRectButton(
                            icon: followStep == 0
                                ? Icons.person_add
                                : followStep == 1
                                ? Icons.control_point
                                : followStep == 2
                                ? Icons.remove_circle_outline
                                : Icons.person_remove,
                            onPressed: () async {
                              switch (followStep) {
                                case 0:
                                  await UserFollowService().followUser(currentUserId, widget.userId);
                                  _showActionLabel('Followed');
                                  break;
                                case 1:
                                  final doc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userId)
                                      .get();
                                  final data = doc.data();
                                  if (data == null) return;
                                  await UserFollowService().addToTrainingCircle(currentUserId, {
                                    'userId': widget.userId,
                                    'displayName': data['displayName'],
                                    'profileImageUrl': data['profileImageUrl'],
                                    'title': data['title'],
                                  });
                                  _showActionLabel('Added to Circle');
                                  break;
                                case 2:
                                  await UserFollowService()
                                      .removeFromTrainingCircle(currentUserId, widget.userId);
                                  _showActionLabel('Removed');
                                  break;
                                default:
                                  await UserFollowService().unfollowUser(currentUserId, widget.userId);
                                  _showActionLabel('Unfollowed');
                              }
                              setState(() {}); // UI will update via streams
                            },
                          ),
                          const SizedBox(width: 16),
                          _iconRectButton(
                            icon: _showBeforeAfter
                                ? Icons.dynamic_feed
                                : Icons.compare_arrows,
                            onPressed: _hasEnoughForBA
                                ? () => setState(
                                    () => _showBeforeAfter = !_showBeforeAfter)
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
                );
              },
            ),
            const SizedBox(height: 20),
            if (_publicBlocks.isNotEmpty) ...[
              PublicCustomBlockGrid(
                images: _publicBlockImages,
                names: _publicBlockNames,
                onAdd: (i) => _addPublicBlock(i),
              ),
              const SizedBox(height: 20),
            ],
            if (showTimeline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: .2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimelinePublic(
                      userId: widget.userId,
                      checkInInfo: showCheckInInfo,
                      showBeforeAfter: _showBeforeAfter,
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
