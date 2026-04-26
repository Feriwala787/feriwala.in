import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'cod';
  bool _placing = false;
  int _selectedAddressIndex = 0;
  List<dynamic> _activePromos = [];
  bool _promoLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivePromos();
    });
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

  Future<void> _addAddress() async {
    final labelCtrl = TextEditingController(text: 'Home');
    final line1Ctrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool isDefault = false;
    double? lat;
    double? lng;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => AlertDialog(
        title: const Text('Add Delivery Address'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
              TextField(controller: line1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1 *')),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City *')),
              TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State *')),
              TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'Pincode *')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async {
                  final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
                  lat = pos.latitude; lng = pos.longitude;
                  setModalState(() {});
                }, icon: const Icon(Icons.my_location), label: const Text('Pin current location'))),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isDefault,
                onChanged: (v) => setModalState(() => isDefault = v),
                title: const Text('Set as default'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      )),
    );

    if (ok != true) return;

    try {
      await ApiService().post('/auth/addresses', body: {
        'label': labelCtrl.text.trim(),
        'addressLine1': line1Ctrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'pincode': pinCtrl.text.trim(),
        'isDefault': isDefault,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      await context.read<AuthProvider>().init();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address added')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _applyPromo(String code) async {
    try {
      await context.read<CartProvider>().applyPromo(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$code applied')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();

    if (cart.items.isEmpty) return;
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue checkout.'), backgroundColor: Colors.orange),
      );
      await Navigator.pushNamed(context, '/login');
      if (context.read<AuthProvider>().isAuthenticated) {
        return _placeOrder();
      }
      return;
    }

    if (auth.user == null || (auth.user!['addresses'] as List?)?.isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address first'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _placing = true);
    try {
      final addresses = auth.user!['addresses'] as List;
      final address = addresses[_selectedAddressIndex];

      final res = await ApiService().post('/orders', body: {
        'shopId': cart.shopId,
        'items': cart.items.map((i) => i.toOrderItem()).toList(),
        'deliveryAddress': address,
        'paymentMethod': _paymentMethod,
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
      });

      cart.clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        Navigator.pushNamed(context, '/order-tracking', arguments: res['data']['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            if (addresses.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No addresses saved. Add one now.'))),
            ...addresses.asMap().entries.map((entry) {
              final i = entry.key;
              final addr = entry.value;
              return RadioListTile<int>(
                value: i,
                groupValue: _selectedAddressIndex,
                onChanged: (v) => setState(() => _selectedAddressIndex = v!),
                title: Text(addr['label'] ?? 'Address ${i + 1}'),
                subtitle: Text('${addr['addressLine1']}, ${addr['city']} - ${addr['pincode']}'),
                activeColor: const Color(0xFFF47721),
              );
            }),

            const SizedBox(height: 16),
            const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...['cod', 'online', 'upi', 'card'].map((method) => RadioListTile<String>(
                  value: method,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  title: Text({
                    'cod': 'Cash on Delivery',
                    'online': 'Online Payment',
                    'upi': 'UPI',
                    'card': 'Card',
                  }[method]!),
                  activeColor: const Color(0xFFF47721),
                )),

            const SizedBox(height: 16),
            const Text('Active Promo Codes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_promoLoading)
              const Center(child: CircularProgressIndicator())
            else if (_activePromos.isEmpty)
              const Text('No active promo codes available right now.')
            else
              ..._activePromos.map((promo) => Card(
                    child: ListTile(
                      title: Text(promo['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${promo['description'] ?? ''}\nMin order INR ${promo['minOrderAmount']}'),
                      trailing: TextButton(
                        onPressed: () => _applyPromo(promo['code']),
                        child: const Text('Apply'),
                      ),
                    ),
                  )),

            const SizedBox(height: 16),
            const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...cart.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${item.name} x${item.quantity}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('INR ${item.total.toStringAsFixed(2)}'),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Subtotal'),
                      Text('INR ${cart.subtotal.toStringAsFixed(2)}'),
                    ]),
                    if (cart.discount > 0)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Discount', style: TextStyle(color: Colors.green)),
                        Text('-INR ${cart.discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                      ]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('INR ${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF47721))),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _placing ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF47721),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _placing
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('Place Order - INR ${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
