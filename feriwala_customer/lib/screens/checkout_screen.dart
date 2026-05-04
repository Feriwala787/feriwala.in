import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 0;
  String _paymentMethod = 'cod';
  bool _placing = false;
  int _selectedAddressIndex = 0;
  List<dynamic> _activePromos = [];
  bool _promoLoading = false;
  String? _serviceabilityMessage;
  final String _clientOrderId = DateTime.now().millisecondsSinceEpoch.toString();

  double get _deliveryFee => 30;
  double get _taxRate => 0.05;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActivePromos());
  }

  Future<void> _loadActivePromos() async { final cart = context.read<CartProvider>(); if (cart.shopId == null) return;
    setState(() => _promoLoading = true);
    try { final res = await ApiService().get('/promos/shop/${cart.shopId}'); setState(() => _activePromos = res['data'] ?? []);} catch (_) { setState(() => _activePromos = []);} finally { if (mounted) setState(() => _promoLoading = false);} }

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

    Future<void> useCurrentLocation(StateSetter setModalState) async {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      lat = pos.latitude; lng = pos.longitude; accuracy = pos.accuracy;
      setModalState(() {});
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => AlertDialog(
        title: const Text('Add Delivery Address'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(children: [
              DropdownButtonFormField<String>(value: label, items: const [DropdownMenuItem(value: 'Home', child: Text('Home')), DropdownMenuItem(value: 'Work', child: Text('Work')), DropdownMenuItem(value: 'Other', child: Text('Other'))], onChanged: (v) => setModalState(() => label = v ?? 'Home')),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Receiver Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *'), keyboardType: TextInputType.phone, validator: (v) => (v != null && v.trim().length >= 10) ? null : 'Enter valid phone'),
              TextFormField(controller: line1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1 *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: landmarkCtrl, decoration: const InputDecoration(labelText: 'Landmark')),
              TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              TextFormField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'Pincode *'), keyboardType: TextInputType.number, validator: (v) => (v != null && v.trim().length == 6) ? null : '6-digit pincode'),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => useCurrentLocation(setModalState), icon: const Icon(Icons.my_location), label: const Text('Use this location')),
              if (lat != null) Text('Location pinned (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}) • ±${(accuracy ?? 0).round()}m', style: const TextStyle(fontSize: 12, color: Colors.green)),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: isDefault, onChanged: (v) => setModalState(() => isDefault = v), title: const Text('Set as default')),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (!(formKey.currentState?.validate() ?? false)) return; Navigator.pop(ctx, true); }, child: const Text('Save'))],
      )),
    );
    if (ok != true) return;
    await ApiService().post('/auth/addresses', body: {'label': label, 'addressLine1': line1Ctrl.text.trim(), 'landmark': landmarkCtrl.text.trim(), 'city': cityCtrl.text.trim(), 'state': stateCtrl.text.trim(), 'pincode': pinCtrl.text.trim(), 'receiverName': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'isDefault': isDefault, if (lat != null) 'latitude': lat, if (lng != null) 'longitude': lng});
    await context.read<AuthProvider>().init();
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];
    if (cart.items.isEmpty || addresses.isEmpty) return;
    setState(() => _placing = true);
    try {
      final address = addresses[_selectedAddressIndex];
      final res = await ApiService().post('/orders', headers: {'Idempotency-Key': _clientOrderId}, body: {'clientOrderId': _clientOrderId, 'shopId': cart.shopId, 'items': cart.items.map((i) => i.toOrderItem()).toList(), 'deliveryAddress': address, 'paymentMethod': _paymentMethod, if (cart.promoCode != null) 'promoCode': cart.promoCode});
      cart.clearCart();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      Navigator.pushNamed(context, '/order-tracking', arguments: res['data']['id']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _placing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];
    final tax = cart.subtotal * _taxRate;
    final grandTotal = cart.total + tax + _deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () { if (_step < 3) setState(() => _step += 1); else _placeOrder(); },
        onStepCancel: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
        controlsBuilder: (context, details) => Row(children: [ElevatedButton(onPressed: details.onStepContinue, child: Text(_step == 3 ? 'Place Order' : 'Continue')), const SizedBox(width: 8), if (_step > 0) TextButton(onPressed: details.onStepCancel, child: const Text('Back'))]),
        steps: [
          Step(title: const Text('Cart'), isActive: _step >= 0, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...cart.items.map((i) => Text('${i.name} x${i.quantity}  INR ${i.total.toStringAsFixed(2)}')),
            const SizedBox(height: 8),
            Text('Subtotal: INR ${cart.subtotal.toStringAsFixed(2)}'),
          ])),
          Step(title: const Text('Address'), isActive: _step >= 1, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add), label: const Text('Add address')),
            ...addresses.asMap().entries.map((e) => RadioListTile<int>(value: e.key, groupValue: _selectedAddressIndex, onChanged: (v) => setState(() => _selectedAddressIndex = v!), title: Text('${e.value['label'] ?? 'Address'} • ${e.value['pincode']}'), subtitle: Text(e.value['addressLine1'] ?? ''))),
            if (_serviceabilityMessage != null) Text(_serviceabilityMessage!, style: const TextStyle(color: Colors.orange)),
          ])),
          Step(title: const Text('Payment'), isActive: _step >= 2, content: Column(children: [
            RadioListTile<String>(value: 'cod', groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!), title: const Text('Cash on Delivery')),
            RadioListTile<String>(value: 'upi', groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!), title: const Text('UPI (Beta)')),
            RadioListTile<String>(value: 'card', groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!), title: const Text('Card (Beta)')),
          ])),
          Step(title: const Text('Review'), isActive: _step >= 3, content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Discount: INR ${cart.discount.toStringAsFixed(2)}'),
            Text('Delivery Fee: INR ${_deliveryFee.toStringAsFixed(2)}'),
            Text('Taxes: INR ${tax.toStringAsFixed(2)}'),
            Text('Total: INR ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Estimated delivery: 25-45 mins'),
            const Text('Cancellation available before pickup.'),
          ])),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: _placing ? null : _placeOrder, child: _placing ? const CircularProgressIndicator() : Text('Place Order - INR ${grandTotal.toStringAsFixed(2)}')),
      ),
    );
  }
}
