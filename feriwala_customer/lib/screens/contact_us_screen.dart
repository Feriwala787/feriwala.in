import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact Us', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _contactCard(
              icon: Icons.email_outlined,
              title: 'Customer Support',
              subtitle: 'support@feriwala.in',
              detail: 'Mon-Sat, 9:00 AM – 8:00 PM IST',
              onTap: () => launchUrl(Uri.parse('mailto:support@feriwala.in')),
            ),
            _contactCard(
              icon: Icons.business_outlined,
              title: 'Business Enquiries',
              subtitle: 'business@feriwala.in',
              detail: 'For shop partnerships & collaborations',
              onTap: () => launchUrl(Uri.parse('mailto:business@feriwala.in')),
            ),
            _contactCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy & Data Requests',
              subtitle: 'privacy@feriwala.in',
              detail: 'Account deletion, data access requests',
              onTap: () => launchUrl(Uri.parse('mailto:privacy@feriwala.in')),
            ),
            _contactCard(
              icon: Icons.report_outlined,
              title: 'Grievance Officer',
              subtitle: 'grievance@feriwala.in',
              detail: 'Response within 48 hours',
              onTap: () => launchUrl(Uri.parse('mailto:grievance@feriwala.in')),
            ),
            const SizedBox(height: 24),
            const Text('Registered Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Feriwala\nIndia', style: TextStyle(fontSize: 14, height: 1.6)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String detail,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF47721)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(color: Color(0xFFF47721), fontSize: 13)),
            Text(detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        trailing: const Icon(Icons.open_in_new, size: 16),
        onTap: onTap,
      ),
    );
  }
}
