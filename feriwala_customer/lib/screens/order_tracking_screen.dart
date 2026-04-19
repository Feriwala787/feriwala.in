import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  List<dynamic> _returnRequests = [];
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
      final allReturns = returnsRes['data'] as List? ?? [];
      setState(() {
        _order = res['data'];
        _returnRequests = allReturns.where((item) => item['orderId'] == widget.orderId).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  int _currentStep() {
    final status = _order?['status'] ?? 'pending';
    final index = _statusSteps.indexOf(status);
    return index >= 0 ? index : 0;
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

  @override
  Widget build(BuildContext context) {
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
                                          step.replaceAll('_', ' ').toUpperCase(),
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
                                        Text('₹${item['total']}'),
                                      ],
                                    ),
                                  )),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('₹${_order!['total']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                            '#${r['id']} • ${(r['returnType'] ?? 'return').toString().toUpperCase()} • ${(r['status'] ?? '').toString().replaceAll('_', ' ').toUpperCase()}',
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
