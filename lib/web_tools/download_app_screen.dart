import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'poss_drawer.dart';


class DownloadAppScreen extends StatelessWidget {
  const DownloadAppScreen({super.key});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          title: const Text('Get The App'),
        ),
        drawer: const POSSDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'The Lift League app is coming soon to Apple App Store and Google Play Store.',
                textAlign: TextAlign.center,
                softWrap: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _openLink('https://play.google.com/store/apps/details?id=com.theliftleague.app'),
                child: const Text('Google Play Store'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _openLink('https://apps.apple.com/app/id000000000'),
                child: const Text('Apple App Store'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
