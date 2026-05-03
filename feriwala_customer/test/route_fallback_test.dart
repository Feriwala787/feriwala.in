import 'package:feriwala_customer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer app shows invalid route page for malformed product id', (tester) async {
    await tester.pumpWidget(const FeriwalaCustomerApp());

    final context = tester.element(find.byType(MaterialApp));
    Navigator.of(context).pushNamed('/product', arguments: 'abc');
    await tester.pumpAndSettle();

    expect(find.text('Invalid navigation'), findsOneWidget);
    expect(find.text('Could not open route: /product'), findsOneWidget);
  });
}
