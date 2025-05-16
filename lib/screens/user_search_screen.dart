import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lift_league/widgets/user_search_tile.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _loadedUsers = [];
  late final String currentUserId;
  late List<String> _circleIds = [];

  String searchQuery = '';
  Timer? _debounce;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _perPage = 25;

  bool _isCircleLoaded = false;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _loadTrainingCircle();
    setState(() => _isCircleLoaded = true);
    _fetchUsers();
  }

  Future<void> _loadTrainingCircle() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('training_circle')
        .get();

    _circleIds = snapshot.docs.map((doc) => doc.id).toList();
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
        .orderBy('displayName')
        .limit(_perPage);

    if (searchQuery.trim().isNotEmpty) {
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

      // Prioritize circle members
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aInCircle = _circleIds.contains(a.id);
        final bInCircle = _circleIds.contains(b.id);
        if (aInCircle && !bInCircle) return -1;
        if (!aInCircle && bInCircle) return 1;
        return 0;
      });

      _loadedUsers.addAll(docs);
    } else {
      _hasMore = false;
    }

    setState(() => _isLoadingMore = false);

    print('SearchQuery: $searchQuery');
    print('Loaded user count: ${snapshot.docs.length}');

  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: !_isCircleLoaded
                ? const Center(child: CircularProgressIndicator())
                : Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (!_isLoadingMore &&
                        _hasMore &&
                        scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      _fetchUsers();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: _loadedUsers.length,
                    itemBuilder: (context, index) {

                      final doc = _loadedUsers[index];
                      final user = doc.data() as Map<String, dynamic>;
                      final userId = doc.id;

                      if (userId == currentUserId) return const SizedBox.shrink();

                      return UserSearchTile(userId: userId, user: user);
                    },
                  ),
                ),
                if (!_isLoadingMore && _loadedUsers.isEmpty)
                  const Center(
                    child: Text(
                      'No lifters found.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
