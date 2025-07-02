import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'about_screen.dart';
import 'custom_blocks_screen.dart';
import 'poss_block_builder.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'download_app_screen.dart';
import 'web_custom_block_service.dart';
import '../services/promo_popup_service.dart';
import 'web_sign_in_dialog.dart';
import 'auth_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Color? _lightGrey = Colors.grey[400];

/// Entry widget that reacts to Firebase auth changes.
/// When a user signs in or out the `StreamBuilder` rebuilds and shows the
/// appropriate UI without requiring a manual page refresh.
class POSSHomePage extends StatelessWidget {
  const POSSHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          // Logged in: show the main POSS interface.
          return const _POSSHomeView();
        } else {
          // Not logged in: present the sign in dialog. The empty Scaffold acts
          // as a placeholder while the dialog is displayed.
          Future.microtask(() => showWebSignInDialog(context));
          return const Scaffold();
        }
      },
    );
  }
}

class _POSSHomeView extends StatefulWidget {
  const _POSSHomeView({super.key});

  @override
  State<_POSSHomeView> createState() => _POSSHomeViewState();
}

class _POSSHomeViewState extends State<_POSSHomeView> {
  bool _showGrid = false;
  bool _loading = true;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkBlocks();
    // Reload blocks whenever the user signs in or out so the
    // UI reflects the correct state immediately.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _checkBlocks();
    });
  }

  Future<void> _checkBlocks({bool allowThrow = false}) async {
    try {
      // Grab blocks belonging to the currently signed-in user.
      final blocks = await WebCustomBlockService().getCustomBlocks();
      if (!mounted) return;
      setState(() {
        _showGrid = blocks.isNotEmpty;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (allowThrow && isAuthError(e)) {
        rethrow;
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSaved() {
    _checkBlocks();
    if (kIsWeb) {
      PromoPopupService().showPromoDialog(context);
    }
  }

  Future<void> _openMyBlocks() async {
    if (FirebaseAuth.instance.currentUser == null) {
      final signedIn = await showWebSignInDialog(context);
      if (!signedIn) return;
    }
    try {
      await _checkBlocks(allowThrow: true);
    } on FirebaseException catch (e) {
      final reauthed = await promptReAuthIfNeeded(context, e);
      if (reauthed) {
        await _checkBlocks();
      } else {
        return;
      }
    }
    setState(() => _showGrid = true);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_showGrid) {
      body = CustomBlocksScreen(onCreateNew: () {
        setState(() => _showGrid = false);
      });
    } else {
      body = const Center(
        child: Text(
          'There are no saved blocks yet',
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      );
    }

    return DefaultTextStyle(
      style: TextStyle(color: _lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: _lightGrey,
          centerTitle: true,
          title: const Text(
            'Progressive Overload\nScoring System',
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.black54),
                child: Text('Menu'),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('My Blocks'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openMyBlocks();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Block Builder'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => POSSBlockBuilder(onSaved: _onSaved)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Terms of Service'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Get the App'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DownloadAppScreen()),
                  );
                },
              ),
              const Divider(),
              Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return ListTile(
                      leading: const Icon(Icons.login),
                      title: const Text('Sign In'),
                      onTap: () async {
                        Navigator.pop(context);
                        final signedIn = await showWebSignInDialog(context);
                        if (signedIn) await _checkBlocks();
                      },
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign Out'),
                      onTap: () async {
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                        if (mounted) setState(() => _showGrid = false);
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Build Workouts • Stay Motivated\nGet Feedback',
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(fontSize: 14),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
