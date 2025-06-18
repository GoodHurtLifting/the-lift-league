import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchScreen extends StatelessWidget {
  const MerchScreen({super.key});

  Future<void> _openStore() async {
    const url = 'https://theliftleague.com/merch';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color? lightGrey = Colors.grey[400];
    return DefaultTextStyle(
      style: TextStyle(color: lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: lightGrey,
          title: const Text('Merch'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _openStore,
            child: const Text('Visit Store'),
          ),
        ),
      ),
    );
  }
}
