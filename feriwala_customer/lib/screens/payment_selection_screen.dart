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
      appBar: AppBar(title: const Text('Select Payment Method')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PaymentMethodCard(
                  icon: Icons.money,
                  title: 'Cash on Delivery',
                  subtitle: 'Pay when you receive your order',
                  value: 'cod',
                  groupValue: _selectedMethod,
                  onChanged: (v) => setState(() => _selectedMethod = v!),
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  icon: Icons.account_balance_wallet,
                  title: 'UPI',
                  subtitle: 'Google Pay, PhonePe, Paytm',
                  value: 'upi',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  icon: Icons.credit_card,
                  title: 'Credit/Debit Card',
                  subtitle: 'Visa, Mastercard, Rupay',
                  value: 'card',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
                const SizedBox(height: 12),
                _PaymentMethodCard(
                  icon: Icons.account_balance,
                  title: 'Net Banking',
                  subtitle: 'All major banks supported',
                  value: 'netbanking',
                  groupValue: _selectedMethod,
                  onChanged: null,
                  comingSoon: true,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF47721),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Continue'),
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
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
        title: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFF47721) : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFFF47721) : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Coming Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }
}
