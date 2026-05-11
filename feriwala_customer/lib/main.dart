import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/error_reporter.dart';
import 'services/required_permissions_service.dart';
import 'services/location_gate_service.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/address_selection_screen.dart';
import 'screens/payment_selection_screen.dart';
import 'screens/order_review_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/live_map_tracking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/otp_verification_screen.dart';

int? _parseRouteInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

Route<dynamic> _invalidRoute(String routeName) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Invalid navigation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not open route: $routeName'),
        ),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.message('uncaught Flutter error: ${details.exceptionAsString()}');
    if (details.stack != null) {
      ErrorReporter.report(details.exception, details.stack!, context: 'flutter');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(error, stack, context: 'platform');
    return false;
  };

  try {
    await RequiredPermissionsService().requestStartupPermissions();

    await ApiService().init();
  } catch (error, stackTrace) {
    ErrorReporter.report(error, stackTrace, context: 'api-init');
    if (!kReleaseMode) {
      rethrow;
    }
  }
  runApp(const FeriwalaCustomerApp());
}

class FeriwalaCustomerApp extends StatelessWidget {
  const FeriwalaCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CartProvider()..init()),
      ],
      child: LocationGate(
        child: MaterialApp(
        title: 'Feriwala',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF47721),
            primary: const Color(0xFFF47721),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/cart': (context) => const CartScreen(),
          '/checkout': (context) => const CheckoutScreen(),
          '/address-selection': (context) => const AddressSelectionScreen(),
          '/payment-selection': (context) => const PaymentSelectionScreen(),
          '/orders': (context) => const OrdersScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/terms': (context) => const TermsScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/product') {
            final productId = _parseRouteInt(settings.arguments);
            if (productId == null) return _invalidRoute('/product');
            return MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: productId),
            );
          }
          if (settings.name == '/order-tracking') {
            final orderId = _parseRouteInt(settings.arguments);
            if (orderId == null) return _invalidRoute('/order-tracking');
            return MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: orderId),
            );
          }
          if (settings.name == '/live-map-tracking') {
            final orderId = _parseRouteInt(settings.arguments);
            if (orderId == null) return _invalidRoute('/live-map-tracking');
            return MaterialPageRoute(
              builder: (context) => LiveMapTrackingScreen(orderId: orderId),
            );
          }
          if (settings.name == '/category-products') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null) return _invalidRoute('/category-products');
            return MaterialPageRoute(
              builder: (context) => CategoryProductsScreen(
                title: args['title'] as String,
                searchKeys: (args['searchKeys'] as List).cast<String>(),
              ),
            );
          }
          if (settings.name == '/order-review') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null) return _invalidRoute('/order-review');
            return MaterialPageRoute(
              builder: (context) => OrderReviewScreen(
                address: args['address'] as Map<String, dynamic>,
                paymentMethod: args['paymentMethod'] as String,
              ),
            );
          }
          return null;
        },
        onUnknownRoute: (settings) => _invalidRoute(settings.name ?? 'unknown'),
      ),
    ),
    );
  }
}

class LocationGate extends StatefulWidget {
  final Widget child;
  const LocationGate({super.key, required this.child});
  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    await LocationGateService.instance.ensureLocationReady(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
