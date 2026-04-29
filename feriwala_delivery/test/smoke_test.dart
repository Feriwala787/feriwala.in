import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:feriwala_delivery/providers/delivery_auth_provider.dart';
import 'package:feriwala_delivery/screens/delivery_login_screen.dart';

void main() {
  testWidgets('delivery login screen renders without throwing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeliveryAuthProvider(),
        child: const MaterialApp(home: DeliveryLoginScreen()),
      ),
    );
    expect(find.text('Feriwala Delivery'), findsOneWidget);
    expect(find.text('Agent Portal'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
