import 'package:flutter/material.dart';

class POSSScoringTool extends StatelessWidget {
  const POSSScoringTool({super.key});

  @override
  Widget build(BuildContext context) {
    final Color? lightGrey = Colors.grey[400];
    return DefaultTextStyle(
      style: TextStyle(color: lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: lightGrey,
          title: const Text('POSS: Lift League Scoring Tool'),
        ),
        body: const Center(child: Text('Coming Soon')),
      ),
    );
  }
}