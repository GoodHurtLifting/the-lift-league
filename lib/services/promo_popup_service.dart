import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PromoPopupService {
  PromoPopupService._internal();
  static final PromoPopupService _instance = PromoPopupService._internal();
  factory PromoPopupService() => _instance;

  static const _prefsKey = 'promoMessageIndex';
  static const _messages = [
    'Want more training options? Unlock all Lift League blocks in the mobile app.',
    'See how you stack up! Join The Lift League app for real-time leaderboards.',
    'Earn badges for consistency and PRs—track your progress with The Lift League app.',
    'Dig into your progress with a full stats dashboard—available in The Lift League mobile app.',
    'Get inspired—follow other lifters and share your progress in the app!',
    'Get video form tips for every lift—available in The Lift League app.',
    'Looking for something? Use the powerful search tool in The Lift League app.',
    'Stay motivated with your crew—create a Training Circle in the app.',
    'See detailed block summaries and celebrate your wins in The Lift League app.',
    'Share check-ins, track photos, and see your transformation—only in the app.',
    'Drop a ‘clink’ after a great session and connect with your team—try the app!',
    'Chat with your Training Circle and friends in The Lift League app.',
    'Get notified when your friends hit milestones—enable notifications in the app.',
    'Visualize your fitness journey with your personal timeline—start in the app!',
    'Compare your before & after photos and see real progress—feature available in the app!',
  ];

  Future<void> showPromoDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt(_prefsKey) ?? 0;
    final message = _messages[index % _messages.length];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Try The Lift League App'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () async {
              const url = 'https://theliftleague.com/app';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Get the App'),
          ),
        ],
      ),
    );

    index = (index + 1) % _messages.length;
    await prefs.setInt(_prefsKey, index);
  }
}
