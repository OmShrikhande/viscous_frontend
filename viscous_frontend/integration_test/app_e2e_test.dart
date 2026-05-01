import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:viscous_frontend/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OTP flow and 3-tab navigation works', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BusTrackerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Track Your Child\'s Bus'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '9000000000');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Verify OTP'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('ETA'), findsOneWidget);

    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Speed'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned route'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Current:'), findsOneWidget);
  });
}
