import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Select Delivery Address')),
      body: addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No addresses saved', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _addAddress(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF47721),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: RadioListTile<int>(
                          value: index,
                          groupValue: _selectedIndex,
                          onChanged: (v) => setState(() => _selectedIndex = v),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF47721).withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  address['label'] ?? 'Address',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF47721)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(address['receiverName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(address['addressLine1'] ?? ''),
                              if (address['landmark'] != null && (address['landmark'] as String).isNotEmpty)
                                Text('Landmark: ${address['landmark']}'),
                              Text('${address['city']}, ${address['state']} - ${address['pincode']}'),
                              Text('Phone: ${address['phone']}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))],
                  ),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _addAddress(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Address'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _selectedIndex == null
                            ? null
                            : () => Navigator.pop(context, addresses[_selectedIndex!]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF47721),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Deliver Here'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _addAddress() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final line1Ctrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    String label = 'Home';
    bool isDefault = false;
    double? lat;
    double? lng;
    double? accuracy;
    bool fetchingLocation = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Add Delivery Address'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: label,
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Work', child: Text('Work')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setModalState(() => label = value ?? 'Home'),
                    decoration: const InputDecoration(labelText: 'Address Type'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: fetchingLocation
                        ? null
                        : () async {
                            setModalState(() => fetchingLocation = true);
                            try {
                              var permission = await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied) {
                                permission = await Geolocator.requestPermission();
                              }
                              if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Location permission required')),
                                  );
                                }
                                return;
                              }
                              final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                              lat = pos.latitude;
                              lng = pos.longitude;
                              accuracy = pos.accuracy;
                              
                              // Auto-fill city and state (placeholder - you can integrate reverse geocoding)
                              cityCtrl.text = 'Mumbai';
                              stateCtrl.text = 'Maharashtra';
                              
                              setModalState(() {});
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Failed to get location: $e')),
                                );
                              }
                            } finally {
                              setModalState(() => fetchingLocation = false);
                            }
                          },
                    icon: fetchingLocation ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                    label: Text(lat != null ? 'Location Captured' : 'Use Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lat != null ? Colors.green : const Color(0xFFF47721),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  if (lat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '📍 ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Receiver Name *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone *', border: OutlineInputBorder()),
                    validator: (v) => (v != null && v.trim().length >= 10) ? null : 'Enter valid phone',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: line1Ctrl,
                    decoration: const InputDecoration(labelText: 'Address Line 1 *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: landmarkCtrl,
                    decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stateCtrl,
                    decoration: const InputDecoration(labelText: 'State *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pincode *', border: OutlineInputBorder()),
                    validator: (v) => (v != null && v.trim().length == 6) ? null : '6-digit pincode',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDefault,
                    onChanged: (v) => setModalState(() => isDefault = v),
                    title: const Text('Set as default address'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF47721),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await ApiService().post('/auth/addresses', body: {
        'label': label,
        'addressLine1': line1Ctrl.text.trim(),
        'landmark': landmarkCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'pincode': pinCtrl.text.trim(),
        'receiverName': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'isDefault': isDefault,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });

      if (mounted) {
        await context.read<AuthProvider>().init();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add address: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
