import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ShopOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const ShopOrderDetailScreen({super.key, required this.orderId});

  @override
  State<ShopOrderDetailScreen> createState() => _ShopOrderDetailScreenState();
}

class _ShopOrderDetailScreenState extends State<ShopOrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final res = await ShopApiService().get('/orders/${widget.orderId}');
      setState(() { _order = res['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _assignDelivery() async {
    try {
      await ShopApiService().post('/delivery/tasks', body: {
        'orderId': widget.orderId,
        'taskType': 'delivery',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery assigned!'), backgroundColor: Colors.green));
      _loadOrder();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_order?['orderNumber'] ?? 'Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: const Text('Status'),
                          trailing: Text(
                            (_order!['status'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Items
                      const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(_order!['items'] as List? ?? []).map((item) => Card(
                            child: ListTile(
                              title: Text(item['productName'] ?? ''),
                              subtitle: Text('Qty: ${item['quantity']} | Size: ${item['size'] ?? '-'} | Color: ${item['color'] ?? '-'}'),
                              trailing: Text('INR ${item['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          )),
                      const SizedBox(height: 12),

                      // Payment info
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _row('Subtotal', 'INR ${_order!['subtotal']}'),
                              _row('Discount', '-INR ${_order!['discount']}'),
                              _row('Delivery Fee', 'INR ${_order!['deliveryFee']}'),
                              const Divider(),
                              _row('Total', 'INR ${_order!['total']}', bold: true),
                              const SizedBox(height: 8),
                              _row('Payment', (_order!['paymentMethod'] ?? '').toString().toUpperCase()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Delivery address
                      if (_order!['deliveryAddress'] != null)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${_order!['deliveryAddress']['addressLine1'] ?? ''}'),
                                Text('${_order!['deliveryAddress']['city'] ?? ''} - ${_order!['deliveryAddress']['pincode'] ?? ''}'),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Delivery tasks
                      if (_order!['deliveryTasks'] != null && (_order!['deliveryTasks'] as List).isNotEmpty) ...[
                        const Text('Delivery Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ...(_order!['deliveryTasks'] as List).map((task) => Card(
                              child: ListTile(
                                leading: Icon(task['taskType'] == 'delivery' ? Icons.delivery_dining : Icons.keyboard_return, color: const Color(0xFFF47721)),
                                title: Text('${task['taskType']} - ${task['status']}'.replaceAll('_', ' ').toUpperCase()),
                                subtitle: task['agentId'] != null ? Text('Agent: ${task['agentId']}') : const Text('Unassigned'),
                              ),
                            )),
                      ],

                      // Assign delivery button
                      if (_order!['status'] == 'ready_for_pickup')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _assignDelivery,
                              icon: const Icon(Icons.delivery_dining),
                              label: const Text('Assign Delivery'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF47721),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),

                      // Invoice
                      if (_order!['invoice'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt, color: Colors.green),
                              title: Text('Invoice: ${_order!['invoice']['invoiceNumber']}'),
                              subtitle: Text('INR ${_order!['invoice']['total']}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
