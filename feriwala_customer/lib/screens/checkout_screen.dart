import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService().track('begin_checkout');
      _navigateToAddressSelection();
    });
  }

  Future<void> _navigateToAddressSelection() async {
    final auth = context.read<AuthProvider>();
    
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final address = await Navigator.pushNamed(context, '/address-selection');
    
    if (address == null) {
      Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    final paymentMethod = await Navigator.pushNamed(context, '/payment-selection');
    
    if (paymentMethod == null) {
      Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/order-review',
      arguments: {
        'address': address,
        'paymentMethod': paymentMethod,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
