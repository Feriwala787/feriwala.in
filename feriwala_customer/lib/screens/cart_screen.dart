import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../utils/formatters.dart';
import '../widgets/feri_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Image
                              FeriImage(
                                url: item.image,
                                width: 70,
                                height: 70,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(formatInr(item.price),
                                        style: const TextStyle(color: Color(0xFFF47721), fontWeight: FontWeight.bold)),
                                    if (item.size != null || item.color != null)
                                      Text('${item.size ?? ''} ${item.color ?? ''}'.trim(),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              // Quantity
                              Column(
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Increase quantity for ${item.name}',
                                    child: IconButton(
                                      icon: const Icon(Icons.add_circle, color: Color(0xFFF47721)),
                                      onPressed: item.quantity >= 10 ? null : () => cart.updateQuantity(index, item.quantity + 1),
                                      iconSize: 28,
                                    ),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Semantics(
                                    button: true,
                                    label: 'Decrease quantity for ${item.name}',
                                    child: IconButton(
                                      icon: Icon(Icons.remove_circle,
                                          color: item.quantity > 1 ? const Color(0xFFF47721) : Colors.red),
                                      onPressed: () => cart.updateQuantity(index, item.quantity - 1),
                                      iconSize: 28,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => cart.moveToSaved(index),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Promo Code
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PromoCodeInput(),
                ),

                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(formatInr(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const Text('Delivery Fee'), Text(formatInr(30))],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const Text('Taxes (5%)'), Text(formatInr(cart.subtotal * 0.05))],
                      ),
                      if (cart.discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount (${cart.promoCode})', style: const TextStyle(color: Colors.green)),
                            Text('-${formatInr(cart.discount)}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                      ],
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(formatInr(cart.total + 30 + cart.subtotal * 0.05),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/checkout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF47721),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Checkout (${cart.itemCount} items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cart.savedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saved for later', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...cart.savedItems.asMap().entries.map((entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(formatInr(entry.value.price)),
                          trailing: OutlinedButton(
                            onPressed: () => cart.moveToCartFromSaved(entry.key),
                            child: const Text('Move to cart'),
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PromoCodeInput extends StatefulWidget {
  @override
  State<_PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<_PromoCodeInput> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _apply() async {
    if (_controller.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<CartProvider>().applyPromo(_controller.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo applied!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Enter promo code',
              prefixIcon: const Icon(Icons.local_offer_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _apply,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white),
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Apply'),
        ),
      ],
    );
  }
}
