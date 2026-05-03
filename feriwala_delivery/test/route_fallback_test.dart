import 'package:feriwala_delivery/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('delivery app shows invalid route page for malformed task id', (tester) async {
    await tester.pumpWidget(const FeriwalaDeliveryApp());

    final context = tester.element(find.byType(MaterialApp));
    Navigator.of(context).pushNamed('/task-detail', arguments: 'bad');
    await tester.pumpAndSettle();

    expect(find.text('Invalid navigation'), findsOneWidget);
    expect(find.text('Could not open route: /task-detail'), findsOneWidget);
  });
}
