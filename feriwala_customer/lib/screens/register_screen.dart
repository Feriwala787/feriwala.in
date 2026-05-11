import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/appwrite_otp_service.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSendingOtp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    phone = phone.trim();
    if (!phone.startsWith('+')) phone = '+91$phone';
    return phone;
  }

  Future<void> _startRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _formatPhone(_phoneController.text);

    // Step 1: Send OTP via Appwrite
    setState(() => _isSendingOtp = true);
    final sent = await AppwriteOtpService.instance.sendOtp(phone);
    setState(() => _isSendingOtp = false);

    if (!sent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP. Check phone number.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Step 2: Navigate to OTP screen
    if (!mounted) return;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(phone: phone, purpose: 'signup'),
      ),
    );

    if (verified != true) return;

    // Step 3: OTP verified — complete registration with backend
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _phoneController.text.trim(),
            _passwordController.text,
          );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v != null && v.isNotEmpty ? null : 'Required',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+91 ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v != null && v.trim().length >= 10 ? null : 'Enter valid phone',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (auth.isLoading || _isSendingOtp) ? null : _startRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF47721),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: (auth.isLoading || _isSendingOtp)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify & Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text.rich(
                  TextSpan(
                    text: 'By creating an account you agree to our ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      WidgetSpan(child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/terms'),
                        child: const Text('Terms & Conditions', style: TextStyle(fontSize: 12, color: Color(0xFFF47721), decoration: TextDecoration.underline)),
                      )),
                      const TextSpan(text: ' and '),
                      WidgetSpan(child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/privacy'),
                        child: const Text('Privacy Policy', style: TextStyle(fontSize: 12, color: Color(0xFFF47721), decoration: TextDecoration.underline)),
                      )),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
