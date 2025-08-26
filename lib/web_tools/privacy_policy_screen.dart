import 'package:flutter/material.dart';
import 'package:lift_league/web_tools/poss_drawer.dart';
import 'poss_drawer.dart';
import 'package:intl/intl.dart';

Color? _lightGrey = Colors.grey[400];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(color: _lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: _lightGrey,
          title: const Text('Privacy Policy'),
        ),
        drawer: const POSSDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Effective Date: '
                  '${DateFormat.yMMMMd().format(DateTime.now())}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The Lift League ("we", "us", or "our") is committed to protecting '
                  'your privacy. This Privacy Policy explains how we collect, use, '
                  'store, and share your information when you use our mobile app, '
                  'website, or related services (collectively, the "Services").',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Information We Collect',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We collect both personal and non-personal information, including:',
                  style: TextStyle(fontSize: 16),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 24, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Personal Information: Name, email address, password, '
                        'communication records, and other identifiers you provide.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '• Fitness and health data (if you connect external services).',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '• Device & Usage Data: IP address, device type, operating '
                        'system, session info, browser type, and activity on the app.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '• Payment Information: If and when we integrate '
                        'third-party payment processors like Stripe, payment details '
                        'may be collected and processed by them securely.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'How We Use Your Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• To provide, maintain, and improve our Services.',
                          style: TextStyle(fontSize: 16)),
                      Text('• To offer customer support and respond to inquiries.',
                          style: TextStyle(fontSize: 16)),
                      Text(
                        '• To personalize your experience and send service-related notifications.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '• To analyze usage and performance data for internal improvements.',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text('• To comply with legal obligations.',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'How We Store & Protect Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your data is stored securely using industry-standard practices. '
                  'We use Firebase (by Google) and other secure infrastructure '
                  'providers to manage authentication, cloud storage, and app '
                  'performance data.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If and when payments are accepted, all payment processing will be '
                  'handled securely via Stripe, which adheres to PCI-DSS standards '
                  'managed by the PCI Security Standards Council (Visa, MasterCard, '
                  'American Express, Discover).',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sharing & Disclosure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We do not sell or rent your personal information. We only share '
                  'data with trusted third-party services required to operate our '
                  'app (e.g., Firebase, analytics providers, or payment processors), '
                  'and only as needed.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Communications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We may contact you via email or in-app messages for account '
                  'updates, support, important notices, or promotional content. '
                  'You can opt out of promotional emails at any time.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Rights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You may request to access, correct, or delete your personal data '
                  'by contacting us at:',
                  style: TextStyle(fontSize: 16),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 24, top: 8),
                  child: Text(
                    '📧 support@TheLiftLeague.com',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Data Retention',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We retain your data only as long as necessary to provide our '
                  'services, comply with our legal obligations, and resolve disputes.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Policy Updates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We may revise this policy occasionally. Changes take effect '
                  'immediately upon posting. If changes are material, we\'ll notify '
                  'you via the app or email.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you have any questions about this Privacy Policy or wish to '
                  'exercise your data rights, please contact:',
                  style: TextStyle(fontSize: 16),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 24, top: 8),
                  child: Text(
                    '📧 support@TheLiftLeague.com',
                    style: TextStyle(fontSize: 16),
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
