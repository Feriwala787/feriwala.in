import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/error_reporter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  List<dynamic> _returnRequests = [];
  Map<String, dynamic>? _deliveryStatus;
  bool _loading = true;
  final _socketService = SocketService();

  final _statusSteps = [
    'pending', 'confirmed', 'preparing', 'ready_for_pickup',
    'picked_up', 'out_for_delivery', 'delivered',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _listenToUpdates();
  }

  void _listenToUpdates() {
    _socketService.onOrderStatus((data) {
      if (data['orderId'] == widget.orderId) {
        _loadOrder();
      }
    });
    _socketService.onDeliveryStatus((data) {
      if (data['orderId'] == widget.orderId) {
        _loadOrder();
      }
    });
  }

  Future<void> _loadOrder() async {
    try {
      final res = await ApiService().get('/orders/${widget.orderId}');
      final returnsRes = await ApiService().get('/delivery/returns/my');
      final deliveryRes = await ApiService().get('/delivery/order/${widget.orderId}/status');
      final allReturns = returnsRes['data'] as List? ?? [];
      setState(() {
        _order = res['data'];
        _returnRequests = allReturns.where((item) => item['orderId'] == widget.orderId).toList();
        _deliveryStatus = deliveryRes['data'];
        _loading = false;
      });
    } catch (e) {
      ErrorReporter.message('order_tracking_load_failed');
      setState(() => _loading = false);
    }
  }

  int _currentStep() {
    final status = _order?['status'] ?? 'pending';
    final index = _statusSteps.indexOf(status);
    return index >= 0 ? index : 0;
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You can cancel only before dispatch.'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService().put('/orders/${_order!['id']}/cancel', body: {
        'reason': reasonController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully')),
      );
      _loadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showReturnDialog() async {
    if (_order == null) return;
    final items = (_order!['items'] as List? ?? []);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No returnable items found')),
      );
      return;
    }

    int selectedItemId = items.first['id'];
    String returnType = 'return';
    String selectedReason = 'Damaged item';
    String pickupSlot = 'Tomorrow (10 AM - 1 PM)';
    final reasonController = TextEditingController();
    final accountHolderController = TextEditingController();
    final accountNumberController = TextEditingController();
    final ifscController = TextEditingController();
    final bankNameController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Return / Replace Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedItemId,
                  decoration: const InputDecoration(labelText: 'Select item'),
                  items: items
                      .map((item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text('${item['productName']} x${item['quantity']}'),
                          ))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedItemId = val ?? selectedItemId),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: returnType,
                  decoration: const InputDecoration(labelText: 'Request type'),
                  items: const [
                    DropdownMenuItem(value: 'return', child: Text('Return (refund to bank)')),
                    DropdownMenuItem(value: 'replace', child: Text('Replace item')),
                  ],
                  onChanged: (val) => setModalState(() => returnType = val ?? 'return'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(labelText: 'Reason category'),
                  items: const [
                    DropdownMenuItem(value: 'Damaged item', child: Text('Damaged item')),
                    DropdownMenuItem(value: 'Wrong size/fit', child: Text('Wrong size/fit')),
                    DropdownMenuItem(value: 'Color mismatch', child: Text('Color mismatch')),
                    DropdownMenuItem(value: 'Quality issue', child: Text('Quality issue')),
                  ],
                  onChanged: (val) => setModalState(() => selectedReason = val ?? selectedReason),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: pickupSlot,
                  decoration: const InputDecoration(labelText: 'Preferred pickup slot'),
                  items: const [
                    DropdownMenuItem(value: 'Tomorrow (10 AM - 1 PM)', child: Text('Tomorrow (10 AM - 1 PM)')),
                    DropdownMenuItem(value: 'Tomorrow (2 PM - 5 PM)', child: Text('Tomorrow (2 PM - 5 PM)')),
                    DropdownMenuItem(value: 'Day after (10 AM - 1 PM)', child: Text('Day after (10 AM - 1 PM)')),
                  ],
                  onChanged: (val) => setModalState(() => pickupSlot = val ?? pickupSlot),
                ),
                const SizedBox(height: 8),
                if (returnType == 'return') ...[
                  TextField(
                    controller: accountHolderController,
                    decoration: const InputDecoration(labelText: 'Account holder name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: accountNumberController,
                    decoration: const InputDecoration(labelText: 'Account number'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ifscController,
                    decoration: const InputDecoration(labelText: 'IFSC code'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bankNameController,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                await ApiService().post('/delivery/returns', body: {
                  'orderId': _order!['id'],
                  'orderItemId': selectedItemId,
                  'returnType': returnType,
                  'reason': reasonController.text.trim(),
                  'reasonCategory': selectedReason,
                  'preferredPickupSlot': pickupSlot,
                  'bankDetails': {
                    'accountHolder': accountHolderController.text.trim(),
                    'accountNumber': accountNumberController.text.trim(),
                    'ifsc': ifscController.text.trim(),
                    'bankName': bankNameController.text.trim(),
                  },
                });
                if (!context.mounted) return;
                Navigator.pop(context, true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return request submitted')),
      );
      _loadOrder();
    }
  }



  String _labelForStatus(String status) {
    switch (status) {
      case 'pending': return 'Order Received';
      case 'confirmed': return 'Order Confirmed';
      case 'preparing': return 'Being Packed';
      case 'ready_for_pickup': return 'Ready for Pickup';
      case 'picked_up': return 'Picked by Rider';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered';
      default: return status.replaceAll('_', ' ');
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('tel:+919999999999');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    String freshnessText(dynamic updatedAt) {
      if (updatedAt == null) return 'Location unavailable';
      final parsed = DateTime.tryParse(updatedAt.toString());
      if (parsed == null) return 'Location unavailable';
      final mins = DateTime.now().difference(parsed.toLocal()).inMinutes;
      if (mins <= 1) return 'Live now';
      return 'Updated ${mins}m ago';
    }

    return Scaffold(
      appBar: AppBar(title: Text(_order?['orderNumber'] ?? 'Order Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status stepper
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ..._statusSteps.asMap().entries.map((entry) {
                                final i = entry.key;
                                final step = entry.value;
                                final isActive = i <= _currentStep();
                                final isCurrent = i == _currentStep();
                                return Row(
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isActive ? const Color(0xFFF47721) : Colors.grey[300],
                                          ),
                                          child: isActive
                                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                                              : null,
                                        ),
                                        if (i < _statusSteps.length - 1)
                                          Container(
                                            width: 2,
                                            height: 24,
                                            color: isActive ? const Color(0xFFF47721) : Colors.grey[300],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Text(
                                          _labelForStatus(step),
                                          style: TextStyle(
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            color: isActive ? Colors.black : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Need help?', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(onPressed: _contactSupport, icon: const Icon(Icons.call), label: const Text('Call Support')),
                                  OutlinedButton.icon(onPressed: _cancelOrder, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel if eligible')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('Return eligibility: within 7 days of delivery for eligible items.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Order items
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...(_order!['items'] as List? ?? []).map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('${item['productName']} x${item['quantity']}')),
                                        Text('INR ${item['total']}'),
                                      ],
                                    ),
                                  )),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('INR ${_order!['total']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_deliveryStatus?['agent'] != null)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Assigned Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(_deliveryStatus!['agent']['name'] ?? 'Delivery Agent'),
                                Text(_deliveryStatus!['agent']['phone'] ?? '', style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  freshnessText(_deliveryStatus!['agent']['locationUpdatedAt']),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_deliveryStatus?['agent'] != null) const SizedBox(height: 12),

                      if (_returnRequests.isNotEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Return / Refund Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ..._returnRequests.map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.history, size: 16, color: Color(0xFFF47721)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${(r['status'] ?? r['refundStatus'] ?? 'requested').toString().replaceAll('_', ' ')} • ${(r['reasonCategory'] ?? r['reason'] ?? '').toString()}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_order!['status'] == 'pending' || _order!['status'] == 'confirmed')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _cancelOrder,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Cancel Order'),
                          ),
                        ),

                      if (_order!['status'] == 'pending' || _order!['status'] == 'confirmed')
                        const SizedBox(height: 12),

                      // Request return (if delivered)
                      if (_order!['status'] == 'delivered')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _showReturnDialog,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Request Return / Replace'),
                          ),
                        ),

                      if (_returnRequests.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Return Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ..._returnRequests.map((r) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '#${r['id']} - ${(r['returnType'] ?? 'return').toString().toUpperCase()} - ${(r['status'] ?? '').toString().replaceAll('_', ' ').toUpperCase()}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          Text(r['reason'] ?? '', style: const TextStyle(color: Colors.grey)),
                                          if ((r['refundStatus'] ?? '').toString().isNotEmpty)
                                            Text('Refund: ${r['refundStatus']}', style: const TextStyle(color: Colors.green)),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
