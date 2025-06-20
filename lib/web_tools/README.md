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

## Storing a new custom block

`POSSBlockBuilder` converts the builder form into a `CustomBlock` object and then
saves it to Firestore under the signed-in user's document:

```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('custom_blocks')
    .doc(block.id.toString())
    .set(blockData);
```

Each block record includes an `ownerId` field containing the user's UID. Because
blocks are stored inside the user's document they can only be read by that user
when the appropriate security rules are in place.

## Cross‑device access

Any time the auth state changes the home page reloads the user's blocks with the
service above. Once signed in on any device the same Firestore query runs and
returns all blocks owned by that UID, ensuring a consistent list everywhere.

Only the collection scoped to the current UID is queried so there is no chance of
loading another user's blocks.

## Signing out

The drawer displays a **Sign Out** tile whenever a user is authenticated. Pressing
it calls `FirebaseAuth.instance.signOut()` and clears the custom block grid so the
guest view is shown again:

```dart
ListTile(
  leading: const Icon(Icons.logout),
  title: const Text('Sign Out'),
  onTap: () async {
    Navigator.pop(context);
    await FirebaseAuth.instance.signOut();
    setState(() => _showGrid = false);
  },
)
```

The auth listener on `POSSHomePage` then reloads the (now empty) block list,
displaying the default POSS interface for guests.
