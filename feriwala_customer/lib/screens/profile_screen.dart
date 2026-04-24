import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            _ProfileTile(icon: Icons.receipt_long, title: 'My Orders', onTap: () => Navigator.pushNamed(context, '/orders')),
            _ProfileTile(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),
            _ProfileTile(icon: Icons.info_outline, title: 'About', onTap: () {}),
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
