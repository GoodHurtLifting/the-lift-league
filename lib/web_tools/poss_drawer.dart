import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'poss_block_builder.dart';

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
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
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
        ],
      ),
    );
  }
}