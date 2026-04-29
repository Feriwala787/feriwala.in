import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:feriwala_shop/providers/shop_auth_provider.dart';
import 'package:feriwala_shop/screens/shop_login_screen.dart';

void main() {
  testWidgets('shop login screen renders without throwing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ShopAuthProvider(),
        child: const MaterialApp(home: ShopLoginScreen()),
      ),
    );
    expect(find.text('Feriwala Shop'), findsOneWidget);
    expect(find.text('Outlet Management'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
