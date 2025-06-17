import 'package:flutter/material.dart';

const Color lightGrey = Color(0xFFD0D0D0);

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: lightGrey),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          foregroundColor: lightGrey,
          title: const Text('POSS Block Builder'),
        ),
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
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    children: [
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
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '2. Turn every set into one score\n',
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
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    children: [
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
                const Text('Build, score, refine—right in your browser.',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
