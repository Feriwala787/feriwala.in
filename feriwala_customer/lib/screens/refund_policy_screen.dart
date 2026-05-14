import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund & Cancellation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Refund & Cancellation Policy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Last updated: May 2025', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            _section('1. Cancellation by Customer',
              '• Before shop starts preparing: No charge, full refund\n'
              '• After preparation starts: ₹20 cancellation fee\n'
              '• After dispatch: Cannot be cancelled (return after delivery)'),
            _section('2. Cancellation by Feriwala',
              'We may cancel orders due to stock unavailability, serviceability issues, or suspected fraud. In such cases, a full refund is issued with no charges.'),
            _section('3. Returns',
              'Returns are accepted within 24 hours of delivery if:\n'
              '• Item is damaged or defective\n'
              '• Wrong item delivered\n'
              '• Size mismatch from what was ordered\n\n'
              'Items must be unused, unwashed, and with original tags intact.'),
            _section('4. Non-Returnable Items',
              '• Innerwear and undergarments\n'
              '• Items without original tags\n'
              '• Items showing signs of use or washing'),
            _section('5. Refund Timelines',
              '• Online payments (UPI/Card/Net Banking): 5-7 business days to original payment method\n'
              '• Cash on Delivery: Store wallet credit within 24 hours, or bank transfer in 5-7 business days on request'),
            _section('6. How to Request',
              'Open the order in the app → Tap "Return/Refund" → Select reason → Our delivery partner will pick up the item.'),
            _section('7. Contact',
              'For refund queries: support@feriwala.in'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://api.feriwala.in/refund')),
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
