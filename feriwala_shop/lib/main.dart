import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/shop_auth_provider.dart';
import 'screens/shop_login_screen.dart';
import 'screens/shop_dashboard_screen.dart';
import 'screens/shop_products_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/shop_orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/shop_promos_screen.dart';
import 'screens/shop_inventory_screen.dart';
import 'screens/delivery_management_screen.dart';
import 'screens/shop_returns_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShopApiService().init();
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
          '/products': (context) => const ShopProductsScreen(),
          '/add-product': (context) => const AddProductScreen(),
          '/orders': (context) => const ShopOrdersScreen(),
          '/promos': (context) => const ShopPromosScreen(),
          '/inventory': (context) => const ShopInventoryScreen(),
          '/delivery': (context) => const DeliveryManagementScreen(),
          '/returns': (context) => const ShopReturnsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/order-detail') {
            final orderId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (context) => ShopOrderDetailScreen(orderId: orderId),
            );
          }
          return null;
        },
      ),
    );
  }
}
