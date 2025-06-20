# Web Tools

This folder contains the Progressive Overload Scoring System (POSS) widgets used on the web version of Lift League.

The home page listens for FirebaseAuth state changes so that a user's custom POSS blocks are fetched as soon as they sign in and hidden again when they sign out.


## How it works

`POSSHomePage` registers an auth listener in `initState`:

```dart
_authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
  _checkBlocks();
});
```

Whenever the auth status changes, `_checkBlocks()` loads blocks for the current user:

```dart
final blocks = await WebCustomBlockService().getCustomBlocks();
setState(() {
  _showGrid = blocks.isNotEmpty;
  _loading = false;
});
```

`WebCustomBlockService` uses the signed-in user's UID when querying Firestore:

```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) return [];
final snap = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('custom_blocks')
    .get();
```

When the list is empty (for example after signing out), the grid is hidden and the default tool state is shown.
