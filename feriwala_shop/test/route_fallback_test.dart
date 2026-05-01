import 'package:feriwala_shop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shop app shows invalid route page for malformed order id', (tester) async {
    await tester.pumpWidget(const FeriwalaShopApp());

    final context = tester.element(find.byType(MaterialApp));
    Navigator.of(context).pushNamed('/order-detail', arguments: 'bad');
    await tester.pumpAndSettle();

    expect(find.text('Invalid navigation'), findsOneWidget);
    expect(find.text('Could not open route: /order-detail'), findsOneWidget);
  });
}
