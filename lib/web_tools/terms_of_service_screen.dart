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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terms of Service',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Effective Date: June 18, 2025'),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: _lightGrey),
                    children: const [
                      TextSpan(
                        text: 'Welcome to The Lift League ("we", "our", or "us"). '
                            'These Terms of Service ("Terms") govern your use of our '
                            'app, website, and all services provided through them ("Services").\n\n',
                      ),
                      TextSpan(
                        text: '1. Acceptance of Terms\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'By accessing or using The Lift League, you confirm that you\'ve read, '
                            'understood, and agreed to these Terms. You must be at least 18 years '
                            'old or the age of majority in your jurisdiction to use our Services.\n\n',
                      ),
                      TextSpan(
                        text: '2. Account Requirements\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'To use most features, you must create an account and provide accurate, '
                            'complete information. You are responsible for maintaining the '
                            'confidentiality of your login credentials and all activities that occur '
                            'under your account.\n\n',
                      ),
                      TextSpan(
                        text: '3. Use of Services\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'You agree not to:\n',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Reproduce, distribute, or repurpose our training content or scoring system outside of The Lift League platform.'),
                      Text('• Use the platform for any unlawful or unauthorized purpose.'),
                      Text('• Reverse-engineer or tamper with the Services.'),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: _lightGrey),
                    children: const [
                      TextSpan(
                        text: '4. Payments & Subscriptions\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'Some features may require a paid subscription. Fees, billing frequency, '
                            'and terms will be clearly stated at the point of purchase. Payments will '
                            'be processed securely via third-party services (e.g., Stripe). '
                            'Subscriptions auto-renew unless canceled before the billing cycle ends.\n\n',
                      ),
                      TextSpan(
                        text:
                            'We reserve the right to modify pricing at any time. Any pricing errors '
                            'are subject to correction.\n\n',
                      ),
                      TextSpan(
                        text: '5. Refund & Return Policy\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'For physical merchandise, returns are accepted within 14 days if the item '
                            'is unused and returned with all packaging and receipts. Digital '
                            'purchases and journals are non-refundable. Contact '
                            'support@TheLiftLeague.com for return instructions.\n\n',
                      ),
                      TextSpan(
                        text: '6. Modifications to the Service\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'We may add, remove, or modify features at any time without prior notice. '
                            'Access may be temporarily or permanently suspended for any reason, '
                            'including violation of these Terms.\n\n',
                      ),
                      TextSpan(
                        text: '7. Intellectual Property\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'All content, including workouts, scores, branding, text, code, logos, '
                            'images, and videos are property of The Lift League and protected by '
                            'copyright and other intellectual property laws. You may not reuse or '
                            'redistribute any part without our written permission.\n\n',
                      ),
                      TextSpan(
                        text: '8. User-Generated Content\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'If you post or upload content (e.g., progress photos, check-ins, status '
                            'updates), you retain ownership but grant us a non-exclusive license to '
                            'use, display, and distribute your content within the platform and '
                            'related marketing, unless your privacy settings dictate otherwise.\n\n'
                            'You must own or have permission to post any content you upload.\n\n',
                      ),
                      TextSpan(
                        text: '9. Community Features\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'Your public profile (handle, stats, timeline) may be visible to others. '
                            'You can control visibility through privacy settings or opt out of '
                            'community features entirely. If you opt out, social features (e.g., '
                            'likes, comments, visibility on leaderboards or timelines) will be '
                            'disabled.\n\n',
                      ),
                      TextSpan(
                        text: '10. Termination\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'We reserve the right to suspend or terminate your access to the Services '
                            'at any time, especially if you violate these Terms. You may cancel your '
                            'account at any time, but active subscriptions will remain valid through '
                            'the end of the paid period.\n\n',
                      ),
                      TextSpan(
                        text: '11. Disclaimers & Limitation of Liability\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'To the maximum extent allowed by law, we are not liable for:\n',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Any injuries, losses, or damages related to your use of the app or physical activity.'),
                      Text('• Data loss or unauthorized access.'),
                      Text('• Third-party service errors (e.g., payment processors or device integrations).'),
                      Text('• Use the app at your own risk and consult a physician before beginning any fitness program.'),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: _lightGrey),
                    children: const [
                      TextSpan(
                        text: '12. Indemnification\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'You agree to indemnify and hold The Lift League and its affiliates '
                            'harmless from any claims, damages, or liabilities arising from your use '
                            'of the Services or violation of these Terms.\n\n',
                      ),
                      TextSpan(
                        text: '13. Governing Law\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'These Terms are governed by the laws of the State of Delaware. Any '
                            'disputes shall be resolved in courts located in Wilmington, Delaware.\n\n',
                      ),
                      TextSpan(
                        text: '14. Changes to Terms\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'We may update these Terms at any time. Material changes will be '
                            'communicated via app or email. Continued use after changes means you '
                            'accept the updated Terms.\n\n',
                      ),
                      TextSpan(
                        text: '15. Contact\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'For any questions, please contact us at:\n',
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 24, bottom: 16),
                  child: Text('📧 support@TheLiftLeague.com'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
