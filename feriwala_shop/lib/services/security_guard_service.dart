import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityGuardService {
  static const _pinKey = 'shop_security_pin';

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_pinKey) ?? '').isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) == pin;
  }

  Future<bool> guardAction(BuildContext context, {required String title, required String subtitle}) async {
    final exists = await hasPin();
    if (!exists) {
      final createCtrl = TextEditingController();
      final created = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Set Security PIN'),
          content: TextField(
            controller: createCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Create 4-6 digit PIN'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (created != true || createCtrl.text.length < 4) return false;
      await setPin(createCtrl.text);
    }

    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle),
            const SizedBox(height: 8),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Enter Security PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify')),
        ],
      ),
    );

    if (ok != true) return false;
    return verifyPin(pinCtrl.text);
  }
}
