import 'package:flutter/material.dart';

class PaymentSelectionScreen extends StatefulWidget {
  const PaymentSelectionScreen({super.key});

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  String _selectedMethod = 'cod';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _PaymentMethodCard(
                  icon: Icons.money,
                  title: 'Cash on Delivery',
                  subtitle: 'Pay when you receive',
                  value: 'cod',
                  groupValue: _selectedMethod,
                  onChanged: (v) => setState(() => _selectedMethod = v!),
                ),
                const SizedBox(height: 10),
                _PaymentMethodCard(
                  icon: Icons.account_balance_wallet,
                  title: 'UPI',
                  subtitle: 'GPay, PhonePe, Paytm',
                  value: 'upi',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
                const SizedBox(height: 10),
                _PaymentMethodCard(
                  icon: Icons.credit_card,
                  title: 'Card',
                  subtitle: 'Visa, Mastercard, Rupay',
                  value: 'card',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
                const SizedBox(height: 10),
                _PaymentMethodCard(
                  icon: Icons.account_balance,
                  title: 'Net Banking',
                  subtitle: 'All major banks',
                  value: 'netbanking',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withAlpha(30), blurRadius: 6, offset: const Offset(0, -2))],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF47721),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?>? onChanged;
  final bool comingSoon;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Card(
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFFF47721) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: const Color(0xFFF47721),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFF47721) : Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSelected ? const Color(0xFFF47721) : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Soon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }
}
