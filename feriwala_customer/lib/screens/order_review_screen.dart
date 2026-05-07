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
  final String _clientOrderId = DateTime.now().millisecondsSinceEpoch.toString();

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

    if (cart.shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop not selected'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validate serviceability (non-blocking — warn only)
    try {
      await ApiService().post('/orders/serviceability', body: {
        'shopId': cart.shopId,
        'deliveryAddress': widget.address,
      });
    } catch (e) {
      // serviceability check failed — show warning but proceed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Serviceability check: ${mapApiError(e)}'), backgroundColor: Colors.orange),
        );
      }
    }

    final isValidCart = await _validateCartBeforeOrder();
    if (!isValidCart) {
      AnalyticsService().track('place_order_blocked_validation');
      return;
    }

    AnalyticsService().track('place_order_attempt', props: {'paymentMethod': widget.paymentMethod});
    setState(() => _placing = true);
    
    try {
      final orderPayload = {
        'clientOrderId': _clientOrderId,
        'shopId': cart.shopId,
        'items': cart.items.map((i) => i.toOrderItem()).toList(),
        'deliveryAddress': widget.address,
        'paymentMethod': widget.paymentMethod,
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
      };

      debugPrint('Placing order with payload: $orderPayload');

      final res = await ApiService().post(
        '/orders',
        headers: {'Idempotency-Key': _clientOrderId},
        body: orderPayload,
      );

      debugPrint('Order response: $res');

      AnalyticsService().track('place_order_success');
      cart.clearCart();
      
      if (!mounted) return;
      
      final orderId = res['data']?['id'];
      if (orderId == null) {
        throw Exception('Order ID not returned from server');
      }

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      Navigator.pushNamed(context, '/order-tracking', arguments: orderId);
    } catch (e) {
      debugPrint('Order placement error: $e');
      if (mounted) {
        AnalyticsService().track('place_order_failed', props: {'error': e.toString()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${mapApiError(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _placeOrder,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final subtotal = (_quote?['subtotal'] as num?)?.toDouble() ?? cart.subtotal;
    final discount = (_quote?['discount'] as num?)?.toDouble() ?? cart.discount;
    // ₹20 delivery for orders under ₹299, else free
    final deliveryFee = (_quote?['deliveryFee'] as num?)?.toDouble()
        ?? ((subtotal - discount) < 299 ? 20.0 : 0.0);
    final tax = (_quote?['tax'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (_quote?['total'] as num?)?.toDouble()
        ?? (subtotal - discount + deliveryFee + tax);
    final isFreeDelivery = deliveryFee == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Review Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _quoteLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  const Text('Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    child: Column(
                      children: cart.items.asMap().entries.map((entry) {
                        final item = entry.value;
                        final isLast = entry.key == cart.items.length - 1;
                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: item.image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        color: Colors.white,
                                        child: Image.network(item.image!, width: 40, height: 40, fit: BoxFit.contain),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.checkroom, color: Colors.grey, size: 20),
                                    ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('Qty: ${item.quantity} • ₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                              trailing: Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Address
                  const Text('Delivery Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF47721).withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.address['label'] ?? 'Address',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF47721)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(widget.address['receiverName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(widget.address['addressLine1'] ?? '', style: const TextStyle(fontSize: 12)),
                          if (widget.address['landmark'] != null && (widget.address['landmark'] as String).isNotEmpty)
                            Text('Near ${widget.address['landmark']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('${widget.address['city']}, ${widget.address['state']} - ${widget.address['pincode']}', style: const TextStyle(fontSize: 11)),
                          Text('📞 ${widget.address['phone']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method
                  const Text('Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const Icon(Icons.money, color: Color(0xFFF47721), size: 22),
                      title: Text(widget.paymentMethod == 'cod' ? 'Cash on Delivery' : 'Online Payment', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price Breakdown
                  const Text('Bill Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _PriceRow('Subtotal', subtotal),
                          if (discount > 0) _PriceRow('Discount', -discount, color: Colors.green),
                          _PriceRow(
                            isFreeDelivery ? 'Delivery (FREE above ₹299)' : 'Delivery',
                            deliveryFee,
                            color: isFreeDelivery ? Colors.green : null,
                          ),
                          if (tax > 0) _PriceRow('Tax', tax),
                          Divider(height: 16, color: Colors.grey.shade300),
                          _PriceRow('Total', grandTotal, isBold: true, fontSize: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 16),
                            SizedBox(width: 6),
                            Text('⏱️ Delivery in 25-45 mins', style: TextStyle(fontSize: 11, color: Colors.blue)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: Colors.orange, size: 16),
                            SizedBox(width: 6),
                            Text('₹20 cancellation charge if cancelled after placing', style: TextStyle(fontSize: 11, color: Colors.orange)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text('Free delivery on orders above ₹299', style: TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha(30), blurRadius: 6, offset: const Offset(0, -2))],
        ),
        child: ElevatedButton(
          onPressed: _placing ? null : _placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF47721),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: _placing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Place Order • ₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

  const _PriceRow(this.label, this.amount, {this.isBold = false, this.fontSize = 12, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(
            '₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? (amount < 0 ? Colors.green : Colors.black)),
          ),
        ],
      ),
    );
  }
}
