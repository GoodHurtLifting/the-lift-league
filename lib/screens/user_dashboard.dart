import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:lift_league/services/db_service.dart'; // ✅ Import DB Service
import 'package:lift_league/dev/dev_tools.dart'; // ✅ Import Dev Tools
import 'package:lift_league/services/user_stats_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lift_league/data/titles_data.dart';
import 'package:lift_league/screens/settings_screen.dart';
import 'package:lift_league/screens/user_stats_screen.dart';
import 'package:lift_league/widgets/timeline_private.dart';
import 'package:lift_league/widgets/block_grid_section.dart';
import 'package:lift_league/screens/public_profile_screen.dart';
import '../widgets/custom_block_button.dart';
import 'user_search_screen.dart';
import 'chat_list_screen.dart';
import 'training_circle_screen.dart';
import 'package:lift_league/services/title_observer_service.dart';
import 'package:lift_league/services/notifications_service.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final UserStatsService _userStatsService = UserStatsService();

  Map<String, int?> blockInstances = {}; // ✅ Store all block instance IDs
  bool isBlockLoading = true; // ✅ Loading state
  List<String> customBlockNames = [];
  List<int> customBlockIds = [];
  List<String> customBlockImages = [];
  bool isProfileLoading = true;
  String profileImageUrl = 'assets/images/flatLogo.jpg';
  String displayName = '';
  String userTitle = '';
  double totalLbsLifted = 0.0;
  int blocksCompleted = 0;
  bool hasUploadedCheckIn = false;
  bool hasUnread = false;

  @override
  void initState() {
    super.initState();
    TitleObserverService.startObservingTitle();
    // Load profile & block instances immediately
    registerForPushNotifications();
    _loadUserProfile();
    _fetchUserStats();
    _checkUnread();
    _fetchAllBlockInstances().then((_) => _fetchCustomBlocks());
  }

  Future<void> _fetchCustomBlocks() async {
    final db = DBService();
    final blocks = await db.getCustomBlocks(includeDrafts: true);
    setState(() {
      customBlockNames = blocks
          .map((b) =>
              b['isDraft'] == 1 ? "${b['name']} (draft)" : b['name'].toString())
          .toList();
      customBlockIds = blocks.map<int>((b) => b['id'] as int).toList();
      customBlockImages = blocks
          .map<String>((b) => b['coverImagePath']?.toString() ?? 'assets/images/flatLogo.jpg')
          .toList();
    });
  }

  Future<void> _deleteCustomBlock(int id) async {
    await DBService().deleteCustomBlock(id);
    await _fetchCustomBlocks();
  }

  Future<void> registerForPushNotifications() async {
    // Request permissions on iOS, Android 13+, etc.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the FCM token for this device
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      // Print for debugging
      print("FCM Token: $fcmToken");

      // Save the token to Firestore for this user (optional but recommended)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': fcmToken});
      }
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();

    if (data != null) {
      final int completed = data['blocksCompleted'] ?? 0;
      final String? url = data['profileImageUrl'];

      setState(() {
        displayName = data['displayName'] ?? 'New Lifter';
        blocksCompleted = completed;
        userTitle = getUserTitle(completed); // ✅ use correct variable
        totalLbsLifted = (data['totalLbsLifted'] as num?)?.toDouble() ?? 0.0;
        profileImageUrl = (url != null && url.isNotEmpty)
            ? url
            : 'assets/images/flatLogo.jpg';
        isProfileLoading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      print('❌ No image selected');
      return;
    }

    // Crop the image to a square
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Image',
          hideBottomControls: true,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) {
      print('❌ Image crop canceled');
      return;
    }

    try {
      // Resize to 800x800 and compress
      final bytes = await croppedFile.readAsBytes();
      final image = img.decodeImage(bytes);
      final resized = img.copyResize(image!, width: 800, height: 800);
      final compressed = img.encodeJpg(resized, quality: 85);

      final fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$fileName');

      final uploadTask = await ref.putData(Uint8List.fromList(compressed));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        profileImageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated!')),
      );
    } catch (e) {
      print('❌ Image upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload failed. Try again.')),
      );
    }
  }

  Future<void> _fetchAllBlockInstances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = DBService();
    List<Map<String, dynamic>> blockInstancesFromDB =
        await db.getAllBlockInstances(user.uid);

    // ✅ If NO block_instances yet, auto-generate one for each block from the blocks table
    if (blockInstancesFromDB.isEmpty) {
      print("ℹ️ No block_instances found. Auto-starting one for each block...");

      final List<Map<String, dynamic>> allBlocks =
          await db.getAllBlocks(); // <-- New helper you'll need

      for (var block in allBlocks) {
        final String blockName =
            block['blockName']?.toString() ?? 'Unnamed Block';
        await db.insertNewBlockInstance(blockName, user.uid);
      }

      // 🔁 Try again after creating them
      blockInstancesFromDB = await db.getAllBlockInstances(user.uid);
    }

    // ✅ Map block names to their instance IDs
    Map<String, int> tempBlockInstances = {};
    for (var block in blockInstancesFromDB) {
      final String name = block['blockName']?.toString() ?? 'Unnamed Block';
      final int? instanceId = block['blockInstanceId'] as int?;
      if (instanceId != null) {
        tempBlockInstances[name] = instanceId;
      }
    }

    setState(() {
      blockInstances = tempBlockInstances;
      isBlockLoading = false;
    });
  }

  Future<bool> hasUnreadMessages(String currentUserId) async {
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: currentUserId)
        .get();

    for (final chatDoc in chatQuery.docs) {
      final chatId = chatDoc.id;
      final messageQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messageQuery.docs.isNotEmpty) {
        final message = messageQuery.docs.first.data();
        final seenBy = List<String>.from(message['seenBy'] ?? []);
        final senderId = message['senderId'];
        if (senderId != currentUserId && !seenBy.contains(currentUserId)) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _fetchUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final lbs = await _userStatsService.getTotalLbsLifted(user.uid);
    final blocks = await _userStatsService.getTotalCompletedBlocks(user.uid);

    setState(() {
      totalLbsLifted = lbs;
      blocksCompleted = blocks;
    });

    // ✅ Sync to Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'totalLbsLifted': lbs,
      'blocksCompleted': blocks,
    });
  }

  void _showEditDisplayNameDialog() {
    final controller = TextEditingController(text: displayName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Handle'),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'displayName': newName,
                    });
                    setState(() {
                      displayName = newName;
                    });
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUnread(); // in case user navigates away and comes back
  }

  Future<void> _checkUnread() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final result = await hasUnreadMessages(currentUserId);
    if (mounted && result != hasUnread) {
      setState(() => hasUnread = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> workoutImages = [
      'assets/images/PushPullLegs.jpg',
      'assets/images/UpperLower.jpg',
      'assets/images/FullBody.jpg',
      'assets/images/FullBodyPlus.jpg',
      'assets/images/5x5.jpg',
      'assets/images/TexasMethod.jpg',
      'assets/images/WuehrHammer.jpg',
      'assets/images/GranMoreno.jpg',
      'assets/images/BodySplit.jpg',
      'assets/images/Shatner.jpg',
      'assets/images/SuperSplit.jpg',
      'assets/images/PushPullLegsPlus.jpg',
    ];

    final List<String> blockNames = [
      "Push Pull Legs",
      "Upper Lower",
      "Full Body",
      "Full Body Plus",
      "5 X 5",
      "Texas Method",
      "Wuehr Hammer",
      "Gran Moreno",
      "Body Split",
      "Shatner",
      "Super Split",
      "PPL Plus",
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Image.asset(
              'assets/images/flatLogo.jpg',
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'The Lift League',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find Lifters',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          FutureBuilder<bool>(
            future: hasUnreadMessages(FirebaseAuth.instance.currentUser!.uid),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data ?? false;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
                    tooltip: 'Chats',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChatListScreen()),
                      );
                      _checkUnread(); // 🔥 re-check when returning from ChatList
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 1,
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Profile Section
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: profileImageUrl.startsWith('http')
                            ? NetworkImage(profileImageUrl)
                            : AssetImage(profileImageUrl) as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showEditDisplayNameDialog,
                          child: Text(
                            isProfileLoading ? 'Loading...' : displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFC3B3D),
                            ),
                          ),
                        ),
                        Text(userTitle,
                            style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey)),
                        Text("Total Blocks: $blocksCompleted",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white)),
                        Text("Total Workload: ${totalLbsLifted.toString()} lbs",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ✅ Navigation Icons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person,
                          color: Colors.white, size: 28),
                      onPressed: () {
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        if (userId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicProfileScreen(userId: userId),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Training Circle',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TrainingCircleScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.bar_chart,
                          color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserStatsScreen(
                                userId: FirebaseAuth.instance.currentUser!.uid),
                          ),
                        );
                      },
                    ),
                    CustomBlockButton(onReturn: _fetchCustomBlocks),
                    const DevTools(),
                  ],
                ),

                const SizedBox(height: 20),

                // ✅ Grid and Timeline in scrollable area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        BlockGridSection(
                          workoutImages: workoutImages,
                          blockNames: blockNames,
                          blockInstances: blockInstances,
                          isLoading: isBlockLoading,
                          onNewBlockInstanceCreated: (blockName, newId) {
                            setState(() {
                              blockInstances[blockName] = newId;
                            });
                          },
                        ),
                        if (customBlockNames.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          BlockGridSection(
                            workoutImages: customBlockImages,
                            blockNames: customBlockNames,
                            customBlockIds: customBlockIds,
                            blockInstances: blockInstances,
                            isLoading: isBlockLoading,
                            overlayNames: true,
                            onNewBlockInstanceCreated: (blockName, newId) {
                              setState(() {
                                blockInstances[blockName] = newId;
                              });
                            },
                            onDeleteCustomBlock: _deleteCustomBlock,
                          ),
                        ],
                        const SizedBox(height: 20),
                        TimelinePrivate(
                          userId: FirebaseAuth.instance.currentUser!.uid,
                          onCheckInUploaded: () {
                            setState(() {
                              hasUploadedCheckIn = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 10,
            right: 10,
            child: CustomBlockButton(),
          ),
        ],
      ),
    );
  }
}
