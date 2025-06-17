import 'package:flutter/material.dart';
import 'poss_drawer.dart';

Color? _lightGrey = Colors.grey[400];

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(color: _lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: _lightGrey,
          title: const Text('Terms of Service'),
        ),
        drawer: const POSSDrawer(),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Terms of Service content goes here.',
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}
