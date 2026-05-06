import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms & Conditions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Last updated: May 2025', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            _section('1. Acceptance of Terms',
              'By using Feriwala, you agree to these Terms. If you do not agree, please do not use the app.'),
            _section('2. Service Description',
              'Feriwala is a quick-commerce platform that delivers clothing and footwear from local stores to your doorstep. '
              'We act as a marketplace connecting customers with local shop owners.'),
            _section('3. Orders & Payments',
              '• Orders are subject to product availability\n'
              '• We currently support Cash on Delivery (COD)\n'
              '• Prices shown include applicable taxes\n'
              '• We reserve the right to cancel orders due to stock unavailability'),
            _section('4. Delivery',
              '• Delivery times are estimates and may vary\n'
              '• You must be available at the delivery address\n'
              '• Delivery is available within the serviceable area only'),
            _section('5. Returns & Refunds',
              '• Returns are accepted within 24 hours of delivery for damaged or wrong items\n'
              '• Items must be unused and in original condition\n'
              '• Refunds for COD orders are processed as store credit or bank transfer within 5-7 business days'),
            _section('6. User Responsibilities',
              '• Provide accurate delivery address and contact information\n'
              '• Do not misuse the platform or place fraudulent orders\n'
              '• One account per person'),
            _section('7. Intellectual Property',
              'All content, logos, and trademarks on Feriwala are owned by Feriwala. '
              'You may not reproduce or distribute any content without written permission.'),
            _section('8. Limitation of Liability',
              'Feriwala is not liable for delays caused by circumstances beyond our control '
              '(weather, traffic, etc.). Our maximum liability is limited to the order value.'),
            _section('9. Governing Law',
              'These terms are governed by the laws of India. '
              'Disputes shall be subject to the jurisdiction of courts in India.'),
            _section('10. Contact',
              'For any queries: support@feriwala.in'),
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
