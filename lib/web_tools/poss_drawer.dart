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
  final VoidCallback? onHome;
  const POSSDrawer({super.key, this.onHome});

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
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('My Blocks'),
            onTap: () async {
              Navigator.pop(context);
              if (FirebaseAuth.instance.currentUser == null) {
                final signedIn = await showWebSignInDialog(context);
                if (!signedIn) return;
              }
              if (onHome != null) {
                onHome!();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Block Builder'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const POSSBlockBuilder()),
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
            title: const Text('Get the App'),
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