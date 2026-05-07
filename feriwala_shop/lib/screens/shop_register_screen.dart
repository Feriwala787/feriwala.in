import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ShopRegisterScreen extends StatefulWidget {
  const ShopRegisterScreen({super.key});

  @override
  State<ShopRegisterScreen> createState() => _ShopRegisterScreenState();
}

class _ShopRegisterScreenState extends State<ShopRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ShopApiService();
  bool _loading = false;
  bool _obscure = true;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _shopName = TextEditingController();
  final _shopAddress = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gst = TextEditingController();
  String _businessType = 'Clothing Store';
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  final _businessTypes = ['Clothing Store', 'Boutique', 'Multi-brand Outlet', 'Factory Outlet', 'Other'];

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post('/auth/register-shop', body: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'shopName': _shopName.text.trim(),
        'shopAddress': _shopAddress.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
        'businessType': _businessType,
        'gstNumber': _gst.text.trim(),
        'openingTime': _fmt(_openTime),
        'closingTime': _fmt(_closeTime),
      });
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Registration Submitted!'),
          content: const Text('Your shop registration is under review. Admin will approve it shortly. You can login once approved.'),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false, TextInputType? keyboard, String? Function(String?)? validator, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          suffixIcon: suffix,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF47721))),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
        ),
        validator: validator ?? (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(title: const Text('Register Your Shop'), backgroundColor: const Color(0xFF1A1A2E), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Owner Details', style: TextStyle(color: Color(0xFFF47721), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _field(_name, 'Full Name'),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress,
              validator: (v) => v != null && v.contains('@') ? null : 'Valid email required'),
            _field(_phone, 'Phone Number', keyboard: TextInputType.phone,
              validator: (v) => v != null && v.trim().length >= 10 ? null : 'Valid phone required'),
            _field(_password, 'Password', obscure: _obscure,
              suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54), onPressed: () => setState(() => _obscure = !_obscure)),
              validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters'),

            const SizedBox(height: 8),
            const Text('Shop Details', style: TextStyle(color: Color(0xFFF47721), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _field(_shopName, 'Shop Name'),
            _field(_shopAddress, 'Shop Address'),
            _field(_city, 'City'),
            _field(_state, 'State'),
            _field(_pincode, 'Pincode', keyboard: TextInputType.number,
              validator: (v) => v != null && v.trim().length == 6 ? null : 'Valid 6-digit pincode'),
            _field(_gst, 'GST Number (optional)', validator: (_) => null),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: _businessType,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Business Type',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF47721))),
                ),
                items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _businessType = v!),
              ),
            ),

            Row(children: [
              Expanded(child: _timePicker('Opening Time', _openTime, (t) => setState(() => _openTime = t))),
              const SizedBox(width: 12),
              Expanded(child: _timePicker('Closing Time', _closeTime, (t) => setState(() => _closeTime = t))),
            ]),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withAlpha(80))),
              child: const Text('📍 After approval, you will need to seed your shop\'s GPS location by being physically present at the shop.', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay value, void Function(TimeOfDay) onPick) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value);
        if (t != null) onPick(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_fmt(value), style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
      ),
    );
  }
}
