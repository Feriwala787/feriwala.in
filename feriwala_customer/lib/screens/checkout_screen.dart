import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../utils/api_error_mapper.dart';

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
  String _clientOrderId = DateTime.now().millisecondsSinceEpoch.toString();
  Map<String, dynamic>? _quote;
  bool _quoteLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _loadActivePromos(); _loadQuote(); AnalyticsService().track('begin_checkout'); });
  }

  Future<void> _loadActivePromos() async {
    final cart = context.read<CartProvider>();
    if (cart.shopId == null) return;

    setState(() => _promoLoading = true);
    try {
      final res = await ApiService().get('/promos/shop/${cart.shopId}');
      setState(() => _activePromos = res['data'] ?? []);
    } catch (_) {
      setState(() => _activePromos = []);
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
  }



  Future<void> _loadQuote() async {
    final cart = context.read<CartProvider>();
    if (cart.shopId == null || cart.items.isEmpty) return;
    setState(() => _quoteLoading = true);
    try {
      final res = await ApiService().post('/orders/quote', body: {
        'shopId': cart.shopId,
        'items': cart.items.map((i) => i.toOrderItem()).toList(),
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
      });
      setState(() => _quote = res['data']);
    } catch (_) {
      setState(() => _quote = null);
      AnalyticsService().track('checkout_quote_failed');
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _pinCurrentLocation(StateSetter setModalState, void Function(double,double,double) onUpdate) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permanently denied. Enable from settings.')),
        );
      }
      return;
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Enter address manually.')),
        );
      }
      return;
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    onUpdate(pos.latitude, pos.longitude, pos.accuracy);
    setModalState(() {});
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Add Delivery Address'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: label,
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Work', child: Text('Work')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setModalState(() => label = value ?? 'Home'),
                  ),
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Receiver Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  TextFormField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *'), validator: (v) => (v != null && v.trim().length >= 10) ? null : 'Enter valid phone'),
                  TextFormField(controller: line1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1 *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  TextFormField(controller: landmarkCtrl, decoration: const InputDecoration(labelText: 'Landmark')),
                  TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  TextFormField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  TextFormField(controller: pinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode *'), validator: (v) => (v != null && v.trim().length == 6) ? null : '6-digit pincode'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pinCurrentLocation(setModalState, (a, b, c) { lat = a; lng = b; accuracy = c; }),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use this location'),
                  ),
                  if (lat != null)
                    Text('Pinned (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}) ±${(accuracy ?? 0).round()}m', style: const TextStyle(fontSize: 12, color: Colors.green)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDefault,
                    onChanged: (v) => setModalState(() => isDefault = v),
                    title: const Text('Set as default'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

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

    await context.read<AuthProvider>().init();
  }



  bool _isAddressServiceable(Map<String, dynamic> address) {
    final pincode = (address['pincode'] ?? '').toString();
    return pincode.length == 6;
  }

  Future<bool> _validateCartBeforeOrder() async {
    final cart = context.read<CartProvider>();
    for (final item in cart.items) {
      final productRes = await ApiService().get('/products/${item.productId}');
      final product = productRes['data'] as Map<String, dynamic>;
      final latestPrice = (product['sellingPrice'] as num).toDouble();
      final inventory = (product['inventory'] as List?) ?? const [];
      final availableQty = inventory.isNotEmpty ? ((inventory.first['quantity'] ?? 0) as num).toInt() : 0;
      if (availableQty < item.quantity) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient stock for ${item.name}')));
        return false;
      }
      if ((latestPrice - item.price).abs() > 0.01) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('One or more prices changed. Please review cart.')));
        return false;
      }
    }
    return true;
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];

    if (cart.items.isEmpty || addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items and delivery address first.')));
      return;
    }

    final selectedAddress = addresses[_selectedAddressIndex];
    if (!_isAddressServiceable(selectedAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address pincode is not serviceable yet.')));
      return;
    }

    final isValidCart = await _validateCartBeforeOrder();
    if (!isValidCart) { AnalyticsService().track('place_order_blocked_validation'); return; }

    AnalyticsService().track('place_order_attempt', props: {'paymentMethod': _paymentMethod});
    setState(() => _placing = true);
    try {
      final address = addresses[_selectedAddressIndex];
      final res = await ApiService().post('/orders',
          headers: {'Idempotency-Key': _clientOrderId},
          body: {
            'clientOrderId': _clientOrderId,
            'shopId': cart.shopId,
            'items': cart.items.map((i) => i.toOrderItem()).toList(),
            'deliveryAddress': address,
            'paymentMethod': _paymentMethod == 'cod' ? 'cod' : 'cod',
            if (cart.promoCode != null) 'promoCode': cart.promoCode,
          });

      AnalyticsService().track('place_order_success');
      cart.clearCart();
      _clientOrderId = DateTime.now().millisecondsSinceEpoch.toString();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      Navigator.pushNamed(context, '/order-tracking', arguments: res['data']['id']);
    } catch (e) {
      if (mounted) {
        AnalyticsService().track('place_order_failed');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapApiError(e)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];

    final deliveryFee = (_quote?['deliveryFee'] as num?)?.toDouble() ?? 30.0;
    final tax = (_quote?['tax'] as num?)?.toDouble() ?? 0;
    final grandTotal = (_quote?['total'] as num?)?.toDouble() ?? (cart.total + tax + deliveryFee);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step < 3) {
            AnalyticsService().track('checkout_step_continue', props: {'step': _step});
            setState(() => _step += 1);
          } else {
            _placeOrder();
          }
        },
        onStepCancel: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
        steps: [
          Step(
            title: const Text('Cart'),
            isActive: _step >= 0,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...cart.items.map((i) => Text('${i.name} x${i.quantity} • INR ${i.total.toStringAsFixed(2)}')),
              const SizedBox(height: 8),
              Text('Subtotal: INR ${((_quote?['subtotal'] as num?)?.toDouble() ?? cart.subtotal).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              if (_promoLoading) const CircularProgressIndicator(),
              if (!_promoLoading && _activePromos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _activePromos.take(3).map<Widget>((promo) => ActionChip(
                    label: Text(promo['code'] ?? ''),
                    onPressed: () async {
                      try {
                        await context.read<CartProvider>().applyPromo((promo['code'] ?? '').toString());
                        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo applied'))); _loadQuote(); }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapApiError(e))));
                      }
                    },
                  )).toList(),
                ),
            ]),
          ),
          Step(
            title: const Text('Address'),
            isActive: _step >= 1,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add), label: const Text('Add address')),
              ...addresses.asMap().entries.map((entry) => RadioListTile<int>(
                    value: entry.key,
                    groupValue: _selectedAddressIndex,
                    onChanged: (v) => setState(() => _selectedAddressIndex = v ?? 0),
                    title: Text('${entry.value['label'] ?? 'Address'} • ${entry.value['pincode']}'),
                    subtitle: Text(entry.value['addressLine1'] ?? ''),
                  )),
              if (_serviceabilityMessage != null)
                Text(_serviceabilityMessage!, style: const TextStyle(color: Colors.orange)),
            ]),
          ),
          Step(
            title: const Text('Payment'),
            isActive: _step >= 2,
            content: Column(children: [
              RadioListTile<String>(value: 'cod', groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!), title: const Text('Cash on Delivery')),
              RadioListTile<String>(value: 'upi', groupValue: _paymentMethod, onChanged: null, title: const Text('UPI (Coming Soon)')),
              RadioListTile<String>(value: 'card', groupValue: _paymentMethod, onChanged: null, title: const Text('Card (Coming Soon)')),
            ]),
          ),
          Step(
            title: const Text('Review'),
            isActive: _step >= 3,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_quoteLoading) const CircularProgressIndicator(),
              Text('Discount: INR ${((_quote?['discount'] as num?)?.toDouble() ?? cart.discount).toStringAsFixed(2)}'),
              Text('Delivery Fee: INR ${deliveryFee.toStringAsFixed(2)}'),
              Text('Taxes: INR ${tax.toStringAsFixed(2)}'),
              Text('Total: INR ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Estimated delivery: 25-45 mins'),
              const Text('Cancellation available before pickup.'),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _placing ? null : _placeOrder,
          child: _placing ? const CircularProgressIndicator() : Text('Place Order - INR ${grandTotal.toStringAsFixed(2)}'),
        ),
      ),
    );
  }
}
