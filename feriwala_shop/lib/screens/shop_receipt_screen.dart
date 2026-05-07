import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const ShopReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final invoice = order['invoice'] as Map<String, dynamic>? ?? const {};
    final items = (order['items'] as List?) ?? const [];
    final subtotal = (order['subtotal'] ?? 0) as num;
    final total = (order['total'] ?? invoice['total'] ?? 0) as num;
    final taxable = (subtotal - ((order['discount'] ?? 0) as num)).clamp(0, 9999999);
    final gst = (taxable * 0.05);

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt ${invoice['invoiceNumber'] ?? ''}'.trim()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Summary',
            onPressed: () => _shareReceipt(context, invoice, total),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Receipt',
            onPressed: () => _chooseTemplateAndPrint(context, invoice, items, gst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Feriwala', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Quick Commerce Clothing Delivery'),
          const SizedBox(height: 12),
          _tile('Order No', order['orderNumber']?.toString() ?? '-'),
          _tile('Invoice No', invoice['invoiceNumber']?.toString() ?? '-'),
          _tile('Payment', (order['paymentMethod'] ?? '-').toString().toUpperCase()),
          _tile('GSTIN', '29ABCDE1234F1Z5'),
          const SizedBox(height: 12),
          QrImageView(
            data: 'FERIWALA-ORDER-${order['id'] ?? order['orderNumber'] ?? ''}',
            size: 110,
            padding: EdgeInsets.zero,
          ),
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
          _tile('GST (5%)', 'INR ${gst.toStringAsFixed(2)}'),
          _tile('Total', 'INR ${total.toStringAsFixed(2)}', bold: true),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _chooseTemplateAndPrint(context, invoice, items, gst),
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
          ),
          TextButton.icon(
            onPressed: () => _showPrintHistory(context),
            icon: const Icon(Icons.history),
            label: const Text('Reprint History'),
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

  Future<void> _shareReceipt(BuildContext context, Map<String, dynamic> invoice, num total) async {
    final text = 'Feriwala Receipt\nInvoice: ${invoice['invoiceNumber'] ?? '-'}\nOrder: ${order['orderNumber'] ?? '-'}\nTotal: INR ${total.toStringAsFixed(2)}';
    await Share.share(text);
  }

  Future<void> _recordPrintEvent({required String status}) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'shop_receipt_print_history';
    final raw = prefs.getStringList(key) ?? [];
    raw.insert(
      0,
      jsonEncode({
        'orderId': order['id'],
        'orderNumber': order['orderNumber'],
        'at': DateTime.now().toIso8601String(),
        'status': status,
      }),
    );
    await prefs.setStringList(key, raw.take(50).toList());
  }

  Future<void> _showPrintHistory(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('shop_receipt_print_history') ?? [];
    final rows = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).where((e) => '${e['orderId']}' == '${order['id']}').toList();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: [
          const ListTile(title: Text('Reprint History')),
          ...rows.map((r) => ListTile(
                leading: Icon(r['status'] == 'success' ? Icons.check_circle : Icons.error, color: r['status'] == 'success' ? Colors.green : Colors.red),
                title: Text('${r['at']}'),
                subtitle: Text('Status: ${r['status']}'),
              )),
          if (rows.isEmpty) const ListTile(title: Text('No print history for this order')),
        ],
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, Map<String, dynamic> invoice, List<dynamic> items, num gst) async {
    await _printReceiptWithTemplate(context, invoice, items, gst, isThermal: false);
  }

  Future<void> _chooseTemplateAndPrint(BuildContext context, Map<String, dynamic> invoice, List<dynamic> items, num gst) async {
    final template = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Print Template'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'thermal'), child: const Text('Thermal 58mm')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'a4'), child: const Text('A4')),
        ],
      ),
    );
    if (template == null) return;
    await _printReceiptWithTemplate(context, invoice, items, gst, isThermal: template == 'thermal');
  }

  Future<void> _printReceiptWithTemplate(
    BuildContext context,
    Map<String, dynamic> invoice,
    List<dynamic> items,
    num gst, {
    required bool isThermal,
  }) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: isThermal ? PdfPageFormat.roll57 : PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Feriwala', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Quick Commerce Clothing Delivery'),
                    pw.Text('GSTIN: 29ABCDE1234F1Z5'),
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
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal'), pw.Text('INR ${order['subtotal'] ?? 0}')]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount'), pw.Text('-INR ${order['discount'] ?? 0}')]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Delivery'), pw.Text('INR ${order['deliveryFee'] ?? 0}')]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GST (5%)'), pw.Text('INR ${gst.toStringAsFixed(2)}')]),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('INR ${order['total'] ?? invoice['total'] ?? 0}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text('Digitally signed by Feriwala POS', style: const pw.TextStyle(fontSize: 9)),
                  ],
                );
              },
            ),
          );
          return doc.save();
        },
      );
      await _recordPrintEvent(status: 'success');
    } catch (e) {
      await _recordPrintEvent(status: 'failed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print receipt: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
