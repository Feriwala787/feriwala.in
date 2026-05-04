import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ShopReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const ShopReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final invoice = order['invoice'] as Map<String, dynamic>? ?? const {};
    final items = (order['items'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt ${invoice['invoiceNumber'] ?? ''}'.trim()),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Receipt',
            onPressed: () => _printReceipt(context, invoice, items),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile('Order No', order['orderNumber']?.toString() ?? '-'),
          _tile('Invoice No', invoice['invoiceNumber']?.toString() ?? '-'),
          _tile('Payment', (order['paymentMethod'] ?? '-').toString().toUpperCase()),
          const SizedBox(height: 12),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...items.map((item) => Card(
                child: ListTile(
                  title: Text(item['productName']?.toString() ?? '-'),
                  subtitle: Text('Qty: ${item['quantity'] ?? 0}'),
                  trailing: Text('INR ${item['total'] ?? 0}'),
                ),
              )),
          const SizedBox(height: 12),
          _tile('Subtotal', 'INR ${order['subtotal'] ?? 0}'),
          _tile('Discount', '-INR ${order['discount'] ?? 0}'),
          _tile('Delivery Fee', 'INR ${order['deliveryFee'] ?? 0}'),
          _tile('Total', 'INR ${order['total'] ?? invoice['total'] ?? 0}', bold: true),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _printReceipt(context, invoice, items),
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    BuildContext context,
    Map<String, dynamic> invoice,
    List<dynamic> items,
  ) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Feriwala Receipt', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Invoice: ${invoice['invoiceNumber'] ?? '-'}'),
                    pw.Text('Order: ${order['orderNumber'] ?? '-'}'),
                    pw.Text('Payment: ${(order['paymentMethod'] ?? '-').toString().toUpperCase()}'),
                    pw.SizedBox(height: 12),
                    ...items.map(
                      (item) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text('${item['productName'] ?? '-'} x${item['quantity'] ?? 0}')),
                          pw.Text('INR ${item['total'] ?? 0}'),
                        ],
                      ),
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [pw.Text('Total'), pw.Text('INR ${order['total'] ?? invoice['total'] ?? 0}')],
                    ),
                  ],
                );
              },
            ),
          );
          return doc.save();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print receipt: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
