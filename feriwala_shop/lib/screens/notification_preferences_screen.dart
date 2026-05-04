import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _newOrder = true;
  bool _slaRisk = true;
  bool _reassignNeeded = true;
  bool _returnPickup = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newOrder = prefs.getBool('notif_new_order') ?? true;
      _slaRisk = prefs.getBool('notif_sla_risk') ?? true;
      _reassignNeeded = prefs.getBool('notif_reassign_needed') ?? true;
      _returnPickup = prefs.getBool('notif_return_pickup') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('New Order Alerts'),
            subtitle: const Text('Notify when a new order is created.'),
            value: _newOrder,
            onChanged: (v) { setState(() => _newOrder = v); _save('notif_new_order', v); },
          ),
          SwitchListTile(
            title: const Text('SLA Risk Alerts'),
            subtitle: const Text('Notify when order/task SLA turns warning/critical.'),
            value: _slaRisk,
            onChanged: (v) { setState(() => _slaRisk = v); _save('notif_sla_risk', v); },
          ),
          SwitchListTile(
            title: const Text('Reassign Needed Alerts'),
            subtitle: const Text('Notify when dispatch reassign is recommended.'),
            value: _reassignNeeded,
            onChanged: (v) { setState(() => _reassignNeeded = v); _save('notif_reassign_needed', v); },
          ),
          SwitchListTile(
            title: const Text('Return Pickup Alerts'),
            subtitle: const Text('Notify about return pickup planning updates.'),
            value: _returnPickup,
            onChanged: (v) { setState(() => _returnPickup = v); _save('notif_return_pickup', v); },
          ),
        ],
      ),
    );
  }
}
