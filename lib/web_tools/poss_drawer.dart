import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'poss_block_builder.dart';
import 'terms_of_service_screen.dart';
import 'download_app_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';
import 'web_sign_in_dialog.dart';

class POSSDrawer extends StatelessWidget {
  final Future<void> Function()? onMyBlocks;
  final VoidCallback? onOpenBuilder;
  const POSSDrawer({super.key, this.onMyBlocks, this.onOpenBuilder});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black54),
            child: Text('Menu'),
          ),
          // My Blocks
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('My Blocks'),
            onTap: () async {
              Navigator.pop(context);
              if (onMyBlocks != null) {
                await onMyBlocks!(); // PAGES handle auth; no duplicate sign-in here
              } else {
                // fallback: keep existing sign-in behavior
                if (FirebaseAuth.instance.currentUser == null) {
                  final signedIn = await showWebSignInDialog(context);
                  if (!signedIn) return;
                }
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          // Block Builder
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Block Builder'),
            onTap: () {
              Navigator.pop(context);
              if (onOpenBuilder != null) {
                onOpenBuilder!(); // lets page supply onSaved version
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const POSSBlockBuilder()),
                );
              }
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
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
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
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Migrate to App'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadAppScreen()),
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
                    await showWebSignInDialog(context);
                  },
                );
              } else {
                return ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }
}