import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/services/user_follow_service.dart';
import 'dart:async';
import 'package:lift_league/widgets/user_search_tile.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Timer? _debounce;
  final List<DocumentSnapshot> _loadedUsers = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _perPage = 25;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;

    setState(() => _isLoadingMore = true);

    if (reset) {
      _loadedUsers.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('showStats', isEqualTo: true)
        .orderBy('displayName')
        .limit(_perPage);

    if (searchQuery.isNotEmpty) {
      query = query
          .startAt([searchQuery])
          .endAt(['$searchQuery\uf8ff']);
    }

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _loadedUsers.addAll(snapshot.docs);
    } else {
      _hasMore = false;
    }

    setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Lifters'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() {
                    searchQuery = value.trim().toLowerCase();
                    _fetchUsers(reset: true);
                  });
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search lifter names...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoadingMore &&
                    _hasMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  _fetchUsers();
                }
                return false;
              },
              child: ListView.builder(
                itemCount: _loadedUsers.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _loadedUsers.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final doc = _loadedUsers[index];
                  final user = doc.data() as Map<String, dynamic>;
                  final userId = doc.id;

                  if (userId == currentUserId) return const SizedBox.shrink();

                  return UserSearchTile(userId: userId, user: user);
                },
              ),
            ),
          ),
        ],
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
}
