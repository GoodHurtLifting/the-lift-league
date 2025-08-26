import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/custom_block_models.dart';
import 'poss_drawer.dart';
import 'custom_blocks_screen.dart';
import 'POSS_block_builder.dart';
import 'web_custom_block_service.dart';
import '../services/promo_popup_service.dart';
import 'web_sign_in_dialog.dart';
import 'auth_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Color? _lightGrey = Colors.grey[400];

/// Entry widget that reacts to Firebase auth changes.
class POSSHomePage extends StatelessWidget {
  const POSSHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show _POSSHomeView; it handles login for protected actions.
    return const _POSSHomeView();
  }
}

class _POSSHomeView extends StatefulWidget {
  const _POSSHomeView({super.key});

  @override
  State<_POSSHomeView> createState() => _POSSHomeViewState();
}

class _POSSHomeViewState extends State<_POSSHomeView> with TickerProviderStateMixin {
  bool _showGrid = false;
  bool _loading = true;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkBlocks();
    // Reload blocks whenever the user signs in or out.
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

  void _openBuilder() {
    // Create a fresh draft so the builder has a non-null customBlockId
    final int draftId = DateTime.now().millisecondsSinceEpoch;

    final draft = CustomBlock(
      id: draftId,
      name: 'Untitled Block',
      numWeeks: 4,
      daysPerWeek: 3,
      workouts: const [],
      isDraft: true,
      coverImagePath: null,
      scheduleType: 'standard',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => POSSBlockBuilder(
          customBlockId: draftId,     // required
          blockInstanceId: null,      // not editing a live run from here
          initialBlock: draft,        // lets the builder prefill
          onSaved: _onSaved,
        ),
      ),
    );
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
      // Empty state: icon bullets with staggered fade/slide + CTA
      body = Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 60), // shift from AppBar
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center, // center the block
            children: [
              // list wrapper so bullets are left-aligned within the centered column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FadeInUp(
                    delayMs: 0,
                    child: const _Bullet(icon: Icons.fitness_center, text: 'Pick Workouts'),
                  ),
                  const SizedBox(height: 8),
                  _FadeInUp(
                    delayMs: 100,
                    child: const _Bullet(icon: Icons.add_circle_outline, text: 'Add Your Lifts'),
                  ),
                  const SizedBox(height: 8),
                  _FadeInUp(
                    delayMs: 200,
                    child: const _Bullet(icon: Icons.calendar_today, text: 'Set Days/Week'),
                  ),
                  const SizedBox(height: 8),
                  _FadeInUp(
                    delayMs: 300,
                    child: const _Bullet(icon: Icons.timelapse, text: 'Choose Total Weeks'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FadeInUp(
                delayMs: 450,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,   // brand red
                    foregroundColor: Colors.black, // black text/icon
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openBuilder,
                  icon: const Icon(Icons.add),
                  label: const Text('Build a Training Block'),
                ),
              ),
            ],
          ),
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
            'Build Scored Workouts\nStay Motivated',
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
        drawer: POSSDrawer(
          onMyBlocks: _openMyBlocks, // uses your auth+reauth flow
          onOpenBuilder: _openBuilder,
        ),
        body: Column(
          children: [
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

/// ─────────────────────────────────────────────────────────
/// UI helpers
/// ─────────────────────────────────────────────────────────

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        Icon(icon, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _FadeInUp extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeInUp({required this.child, this.delayMs = 0});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
