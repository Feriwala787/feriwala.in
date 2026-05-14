import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
              'By downloading, installing, or using the Feriwala mobile application, you agree to be bound by these Terms & Conditions. If you do not agree, please uninstall the app.'),
            _section('2. Service Description',
              'Feriwala is a quick-commerce marketplace that connects customers with local clothing and footwear retailers for rapid delivery. Feriwala acts as an intermediary platform and does not own or stock inventory.'),
            _section('3. Eligibility',
              'You must be at least 18 years old to use Feriwala. By using the app, you represent that you meet this requirement.'),
            _section('4. Account',
              'You are responsible for maintaining the confidentiality of your account credentials. One account per individual. We reserve the right to suspend accounts involved in fraudulent activity.'),
            _section('5. Orders & Pricing',
              '• Orders are subject to product availability and serviceability\n'
              '• Prices displayed include applicable taxes unless stated otherwise\n'
              '• We reserve the right to cancel orders due to stock unavailability, pricing errors, or suspected fraud'),
            _section('6. Payments',
              '• We support Cash on Delivery (COD) and online payments (UPI, cards, net banking) via Razorpay\n'
              '• Online payments are processed securely through Razorpay\'s PCI-DSS compliant infrastructure\n'
              '• Feriwala does not store your card or bank details\n'
              '• Payment is collected at the time of order placement for online payments'),
            _section('7. Delivery',
              '• Estimated delivery: 25-45 minutes from order confirmation\n'
              '• Delivery times may vary due to traffic, weather, or operational constraints\n'
              '• You must be available at the delivery address\n'
              '• Free delivery on orders above ₹299; ₹20 delivery fee otherwise'),
            _section('8. Cancellation',
              '• Orders can be cancelled before the shop starts preparing — no charge\n'
              '• ₹20 cancellation fee applies after preparation begins\n'
              '• Orders cannot be cancelled after dispatch (return after delivery)'),
            _section('9. Returns & Refunds',
              '• Returns accepted within 24 hours of delivery for damaged, defective, or wrong items\n'
              '• Items must be unused, unwashed, with original tags intact\n'
              '• Online payment refunds: 5-7 business days to original payment method\n'
              '• COD refunds: Store wallet credit within 24 hours, or bank transfer in 5-7 days on request\n'
              '• Innerwear and items without tags are non-returnable'),
            _section('10. Intellectual Property',
              'All content, logos, and trademarks on Feriwala are owned by Feriwala. Reproduction or distribution without written permission is prohibited.'),
            _section('11. Limitation of Liability',
              'Feriwala is not liable for delays caused by force majeure events. Our maximum liability is limited to the order value paid by the customer.'),
            _section('12. Governing Law',
              'These terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in India.'),
            _section('13. Contact',
              'For any queries: support@feriwala.in'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://api.feriwala.in/terms')),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View full terms online'),
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
