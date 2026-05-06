import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../utils/api_error_mapper.dart';

class OrderReviewScreen extends StatefulWidget {
  final Map<String, dynamic> address;
  final String paymentMethod;

  const OrderReviewScreen({
    super.key,
    required this.address,
    required this.paymentMethod,
  });

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  bool _placing = false;
  Map<String, dynamic>? _quote;
  bool _quoteLoading = true;
  String _clientOrderId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _loadQuote();
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
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<bool> _validateCartBeforeOrder() async {
    final cart = context.read<CartProvider>();
    for (final item in cart.items) {
      try {
        final productRes = await ApiService().get('/products/${item.productId}');
        final product = productRes['data'] as Map<String, dynamic>;
        final latestPrice = (product['sellingPrice'] as num).toDouble();
        final inventory = (product['inventory'] as List?) ?? const [];
        final availableQty = inventory.isNotEmpty ? ((inventory.first['quantity'] ?? 0) as num).toInt() : 0;
        
        if (availableQty < item.quantity) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Insufficient stock for ${item.name}')),
            );
          }
          return false;
        }
        
        if ((latestPrice - item.price).abs() > 0.01) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('One or more prices changed. Please review cart.')),
            );
          }
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    final cart = context.read<CartProvider>();

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // Validate serviceability
    try {
      await ApiService().post('/orders/serviceability', body: {
        'shopId': cart.shopId,
        'deliveryAddress': widget.address,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapApiError(e)), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final isValidCart = await _validateCartBeforeOrder();
    if (!isValidCart) {
      AnalyticsService().track('place_order_blocked_validation');
      return;
    }

    AnalyticsService().track('place_order_attempt', props: {'paymentMethod': widget.paymentMethod});
    setState(() => _placing = true);
    
    try {
      final res = await ApiService().post(
        '/orders',
        headers: {'Idempotency-Key': _clientOrderId},
        body: {
          'clientOrderId': _clientOrderId,
          'shopId': cart.shopId,
          'items': cart.items.map((i) => i.toOrderItem()).toList(),
          'deliveryAddress': widget.address,
          'paymentMethod': widget.paymentMethod,
          if (cart.promoCode != null) 'promoCode': cart.promoCode,
        },
      );

      AnalyticsService().track('place_order_success');
      cart.clearCart();
      
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      Navigator.pushNamed(context, '/order-tracking', arguments: res['data']['id']);
    } catch (e) {
      if (mounted) {
        AnalyticsService().track('place_order_failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapApiError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final deliveryFee = (_quote?['deliveryFee'] as num?)?.toDouble() ?? 30.0;
    final tax = (_quote?['tax'] as num?)?.toDouble() ?? (cart.subtotal * 0.05);
    final discount = (_quote?['discount'] as num?)?.toDouble() ?? cart.discount;
    final subtotal = (_quote?['subtotal'] as num?)?.toDouble() ?? cart.subtotal;
    final grandTotal = (_quote?['total'] as num?)?.toDouble() ?? (subtotal - discount + deliveryFee + tax);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Order')),
      body: _quoteLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...cart.items.map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: item.image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(item.image!, width: 50, height: 50, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.checkroom, color: Colors.grey),
                                ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('Qty: ${item.quantity} • ₹${item.price.toStringAsFixed(2)}'),
                          trailing: Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )),
                  const SizedBox(height: 24),

                  // Delivery Address
                  const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF47721).withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.address['label'] ?? 'Address',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF47721)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(widget.address['receiverName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(widget.address['addressLine1'] ?? ''),
                          if (widget.address['landmark'] != null && (widget.address['landmark'] as String).isNotEmpty)
                            Text('Landmark: ${widget.address['landmark']}'),
                          Text('${widget.address['city']}, ${widget.address['state']} - ${widget.address['pincode']}'),
                          Text('Phone: ${widget.address['phone']}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Method
                  const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.money, color: Color(0xFFF47721)),
                      title: Text(widget.paymentMethod == 'cod' ? 'Cash on Delivery' : 'Online Payment'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Price Breakdown
                  const Text('Price Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _PriceRow('Subtotal', subtotal),
                          if (discount > 0) _PriceRow('Discount', -discount, color: Colors.green),
                          _PriceRow('Delivery Fee', deliveryFee),
                          _PriceRow('Taxes', tax),
                          const Divider(height: 24),
                          _PriceRow('Total', grandTotal, isBold: true, fontSize: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimated delivery: 25-45 mins\nCancellation available before pickup',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: ElevatedButton(
          onPressed: _placing ? null : _placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF47721),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: _placing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Place Order • ₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final double fontSize;
  final Color? color;

  const _PriceRow(this.label, this.amount, {this.isBold = false, this.fontSize = 14, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(
            '₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? (amount < 0 ? Colors.green : Colors.black)),
          ),
        ],
      ),
    );
  }
}
