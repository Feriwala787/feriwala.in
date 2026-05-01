import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/shop_auth_provider.dart';
import 'screens/shop_login_screen.dart';
import 'screens/shop_dashboard_screen.dart';
import 'screens/shop_orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/shop_promos_screen.dart';
import 'screens/shop_inventory_screen.dart';
import 'screens/delivery_management_screen.dart';
import 'screens/shop_returns_screen.dart';

int? _parseRouteInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

Route<dynamic> _invalidRoute(String routeName) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Invalid navigation')),
      body: Center(child: Text('Could not open route: $routeName')),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Shop uncaught Flutter error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Shop platform error: $error');
    return true;
  };

  try {
    await ShopApiService().init();
  } catch (error) {
    debugPrint('Shop API init failed: $error');
  }
  runApp(const FeriwalaShopApp());
}

class FeriwalaShopApp extends StatelessWidget {
  const FeriwalaShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShopAuthProvider()..init()),
      ],
      child: MaterialApp(
        title: 'Feriwala Shop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A2E),
            primary: const Color(0xFF1A1A2E),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const ShopLoginScreen(),
          '/dashboard': (context) => const ShopDashboardScreen(),
          '/orders': (context) => const ShopOrdersScreen(),
          '/promos': (context) => const ShopPromosScreen(),
          '/inventory': (context) => const ShopInventoryScreen(),
          '/delivery': (context) => const DeliveryManagementScreen(),
          '/returns': (context) => const ShopReturnsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/order-detail') {
            final orderId = _parseRouteInt(settings.arguments);
            if (orderId == null) return _invalidRoute('/order-detail');
            return MaterialPageRoute(
              builder: (context) => ShopOrderDetailScreen(orderId: orderId),
            );
          }
          return null;
        },
        onUnknownRoute: (settings) => _invalidRoute(settings.name ?? 'unknown'),
      ),
    );
  }
}
