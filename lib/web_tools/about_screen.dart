import 'package:flutter/material.dart';
import 'poss_drawer.dart';


Color? lightGrey = Colors.grey[400];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(color: lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: lightGrey,
          title: const Text('POSS Block Builder'),
        ),
        drawer: const POSSDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What it does',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // 1
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                    children: const [
                      TextSpan(
                        text: '1. Build & save structured workouts\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '   Craft multi-week training blocks and store everything in-browser—no downloads, no exports.\n\n',
                      ),
                    ],
                  ),
                ),
                // 2
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                    children: const [
                      TextSpan(
                        text: '2. Turn every workout into a single score to beat\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '   The Progressive Overload Scoring System condenses all your reps, sets, and weights into a single number. Chase that number upward to see—instantly—whether you’re actually making gains.\n\n',
                      ),
                    ],
                  ),
                ),
                // 3
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                    children: const [
                      TextSpan(
                        text: '3. AI checks program balance\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '   An integrated assistant reviews each block for:\n',
                      ),
                    ],
                  ),
                ),
                // AI balance bullet points
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• balanced muscle-group coverage',
                          style: TextStyle(fontSize: 16)),
                      Text(
                          '• rep-scheme fit for your goal (strength / power / hypertrophy)',
                          style: TextStyle(fontSize: 16)),
                      Text('• useful mixes of training styles',
                          style: TextStyle(fontSize: 16)),
                      Text(
                          '• lagging areas (e.g., add triceps to match biceps work)',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                Text('Build, score, refine—right in your browser.',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[350])),
                const SizedBox(height: 6),
                const Text(
                  'Powered by The Lift League',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
