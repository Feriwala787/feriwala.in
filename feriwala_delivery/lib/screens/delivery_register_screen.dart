import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({super.key});

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = DeliveryApiService();
  bool _loading = false;
  bool _obscure = true;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _aadhar = TextEditingController();
  final _emergency = TextEditingController();
  String _vehicleType = 'bike';

  final _vehicleTypes = [
    {'value': 'bike', 'label': '🏍️ Bike'},
    {'value': 'scooter', 'label': '🛵 Scooter'},
    {'value': 'bicycle', 'label': '🚲 Bicycle'},
    {'value': 'walk', 'label': '🚶 Walk'},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post('/auth/register-delivery', body: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'licenseNumber': _license.text.trim(),
        'vehicleType': _vehicleType,
        'vehicleNumber': _vehicleNumber.text.trim(),
        'aadharNumber': _aadhar.text.trim(),
        'emergencyContact': _emergency.text.trim(),
      });
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Registration Submitted!'),
          content: const Text('Your registration is under review. Admin will approve it shortly. You can login once approved.'),
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
      backgroundColor: const Color(0xFF16213E),
      appBar: AppBar(title: const Text('Register as Delivery Agent'), backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Personal Details', style: TextStyle(color: Color(0xFFF47721), fontWeight: FontWeight.bold, fontSize: 14)),
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
            const Text('Vehicle & Documents', style: TextStyle(color: Color(0xFFF47721), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: _vehicleType,
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Vehicle Type',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF47721))),
                ),
                items: _vehicleTypes.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
                onChanged: (v) => setState(() => _vehicleType = v!),
              ),
            ),

            _field(_license, 'Driving License Number',
              validator: (v) => v != null && v.trim().length >= 5 ? null : 'Valid license number required'),
            _field(_vehicleNumber, 'Vehicle Number (optional)', validator: (_) => null),
            _field(_aadhar, 'Aadhar Number', keyboard: TextInputType.number,
              validator: (v) => v != null && v.trim().length == 12 ? null : '12-digit Aadhar required'),
            _field(_emergency, 'Emergency Contact Number', keyboard: TextInputType.phone,
              validator: (v) => v != null && v.trim().length >= 10 ? null : 'Valid phone required'),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(30), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withAlpha(80))),
              child: const Text('ℹ️ Your documents will be verified by admin before approval. You will be able to login once approved.', style: TextStyle(color: Colors.lightBlue, fontSize: 12)),
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
}
