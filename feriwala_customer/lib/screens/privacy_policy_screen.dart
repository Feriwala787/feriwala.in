import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy Policy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Last updated: May 2025', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            _section('1. Information We Collect',
              'We collect information you provide directly:\n'
              '• Name, email address, phone number when you register\n'
              '• Delivery addresses you save\n'
              '• Order history and preferences\n'
              '• Device location (only when you use the app, to find nearby stores)\n'
              '• Device identifiers for push notifications'),
            _section('2. How We Use Your Information',
              '• To process and deliver your orders\n'
              '• To send order status updates via notifications\n'
              '• To show nearby stores and estimated delivery times\n'
              '• To improve our service and fix issues\n'
              '• We do NOT sell your personal data to third parties'),
            _section('3. Location Data',
              'We request location permission to find stores near you and calculate delivery estimates. '
              'Location is only accessed while the app is in use (foreground). '
              'We do not track your location in the background.'),
            _section('4. Data Storage & Security',
              'Your data is stored on secure servers hosted on AWS (Mumbai region). '
              'Passwords are hashed and never stored in plain text. '
              'We use HTTPS for all data transmission.'),
            _section('5. Data Sharing',
              'We share your delivery address and name with our delivery partners solely to fulfil your order. '
              'We do not share your data with advertisers or data brokers.'),
            _section('6. Your Rights',
              'You may:\n'
              '• Request a copy of your data\n'
              '• Request deletion of your account and data\n'
              '• Update your personal information in the Profile section\n\n'
              'To exercise these rights, contact us at privacy@feriwala.in\n\n'
              'Account deletion is processed within 72 hours. Visit https://api.feriwala.in/delete-account for details.'),
            _section('7. Children\'s Privacy',
              'Feriwala is not directed at children under 13. '
              'We do not knowingly collect data from children under 13.'),
            _section('8. Changes to This Policy',
              'We may update this policy. We will notify you of significant changes via the app or email.'),
            _section('9. Contact Us',
              'Feriwala\nEmail: privacy@feriwala.in\nAddress: India'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://api.feriwala.in/privacy')),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View full policy online'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
