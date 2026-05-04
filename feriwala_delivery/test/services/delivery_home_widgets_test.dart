import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feriwala_delivery/screens/delivery_home_screen.dart';

void main() {
  testWidgets('DeliveryErrorState shows message and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryErrorState(
            message: 'Unable to refresh tasks. Please try again.',
            onRetry: () async => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Could not load tasks'), findsOneWidget);
    expect(find.text('Unable to refresh tasks. Please try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retried, true);
  });

  testWidgets('QueuedActionBadge renders pending count', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: QueuedActionBadge(count: 3))));
    expect(find.text('Queued: 3'), findsOneWidget);
  });

  testWidgets('TaskCard disables accept while loading and shows spinner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: const {'id': 11, 'taskType': 'delivery', 'status': 'assigned'},
            onTap: () {},
            onAccept: () {},
            isAccepting: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
