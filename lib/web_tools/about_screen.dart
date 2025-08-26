import 'package:flutter/material.dart';
import 'package:lift_league/web_tools/poss_drawer.dart';


final Color brandRed = Colors.red;
final Color brandBlack = Colors.black;
final Color brandWhite = Colors.white;
final Color? lightGrey = Colors.grey[400];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(color: lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: lightGrey,
          title: const Text('About POSS'),
          centerTitle: true,
        ),
        drawer: const POSSDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandBlack.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: brandRed.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'POSS = Progressive Overload Scoring System',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // What is POSS
                const Text(
                  'What is POSS?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'A simple way to build training blocks and turn every session into a single score you can beat.',
                  style: TextStyle(fontSize: 16, color: lightGrey),
                ),

                const SizedBox(height: 20),
                Divider(color: brandBlack.withOpacity(0.2)),
                const SizedBox(height: 12),

                // What it does
                const Text(
                  'What it does',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const _Bullet(
                  title: 'Build & save structured workouts',
                  body:
                  'Create multi‑week training blocks and keep them in your browser (no downloads required).',
                  icon: Icons.folder,
                ),
                const _Bullet(
                  title: 'Score every workout',
                  body:
                  'POSS condenses sets × reps × weight into one number so progress is obvious.',
                  icon: Icons.score,
                ),
                const _Bullet(
                  title: 'Stay motivated',
                  body:
                  'Your score makes “did I get better?” a yes/no you can see—and chase.',
                  icon: Icons.local_fire_department,
                ),

                const SizedBox(height: 20),
                Divider(color: brandBlack.withOpacity(0.2)),
                const SizedBox(height: 12),

                // Short closer
                Text(
                  'Build. Score. Improve.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: lightGrey,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Powered by The Lift League',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _Bullet({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: Colors.red),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(body),
    );
  }
}
