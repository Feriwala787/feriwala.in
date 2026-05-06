import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/notification_prefs.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _showReferralSheet(BuildContext context, Map<String, dynamic> user) async {
    final code = 'FERI${(user['id'] ?? user['email'] ?? 'USER').toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').padRight(6, 'X').substring(0, 6)}';
    final message = 'Use my Feriwala referral code $code and get rewards on your first order!';
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Refer & Earn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Share your code and earn rewards when friends place their first order.'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Text(code, style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Code'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: message));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral message copied')));
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Copy Invite'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationPrefs(BuildContext context) async {
    final current = await NotificationPrefs.load();
    bool orderUpdates = current['orderUpdates'] ?? true;
    bool returnUpdates = current['returnUpdates'] ?? true;
    bool promotions = current['promotions'] ?? false;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                SwitchListTile(
                  value: orderUpdates,
                  onChanged: (v) => setModalState(() => orderUpdates = v),
                  title: const Text('Order updates'),
                ),
                SwitchListTile(
                  value: returnUpdates,
                  onChanged: (v) => setModalState(() => returnUpdates = v),
                  title: const Text('Return/refund updates'),
                ),
                SwitchListTile(
                  value: promotions,
                  onChanged: (v) => setModalState(() => promotions = v),
                  title: const Text('Offers and promotions'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await NotificationPrefs.save(
                        orderUpdates: orderUpdates,
                        returnUpdates: returnUpdates,
                        promotions: promotions,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification preferences saved')));
                      }
                    },
                    child: const Text('Save Preferences'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    await ApiService().put('/auth/profile', body: {
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
    });
    await context.read<AuthProvider>().init();
  }

  Future<void> _addAddress(BuildContext context) async {
    final labelCtrl = TextEditingController(text: 'Home');
    final line1Ctrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
              TextField(controller: line1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1')),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
              TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State')),
              TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'Pincode')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    await ApiService().post('/auth/addresses', body: {
      'label': labelCtrl.text.trim(),
      'addressLine1': line1Ctrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'state': stateCtrl.text.trim(),
      'pincode': pinCtrl.text.trim(),
    });
    await context.read<AuthProvider>().init();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (!auth.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 82, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Login to access profile, addresses and order history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF47721),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Create account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final addresses = (user['addresses'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFF47721).withAlpha(30),
                    child: Text(
                      (user['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFFF47721)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                  Text(user['phone'] ?? '', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _editProfile(context, user),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved Addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: () => _addAddress(context), icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            ...addresses.map((a) => Card(
                  child: ListTile(
                    title: Text(a['label'] ?? 'Address'),
                    subtitle: Text('${a['addressLine1']}, ${a['city']} ${a['state']} - ${a['pincode']}'),
                  ),
                )),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF47721)),
                title: Text('Rewards Wallet'),
                subtitle: Text('Credits: ₹0 • Tier: Starter • Cashback coming soon'),
              ),
            ),
            const SizedBox(height: 8),
            _ProfileTile(icon: Icons.receipt_long, title: 'My Orders', onTap: () => Navigator.pushNamed(context, '/orders')),
            _ProfileTile(icon: Icons.notifications_outlined, title: 'Notification Preferences', onTap: () => _showNotificationPrefs(context)),
            _ProfileTile(icon: Icons.card_giftcard, title: 'Refer & Earn', onTap: () => _showReferralSheet(context, user)),
            _ProfileTile(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),
            _ProfileTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () => Navigator.pushNamed(context, '/privacy')),
            _ProfileTile(icon: Icons.description_outlined, title: 'Terms & Conditions', onTap: () => Navigator.pushNamed(context, '/terms')),
            _ProfileTile(icon: Icons.info_outline, title: 'About Feriwala v1.1.0', onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Feriwala',
              applicationVersion: '1.1.0',
              applicationLegalese: '© 2025 Feriwala. All rights reserved.',
              children: [const Text('Quick commerce for clothes & footwear.')],
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF47721)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
