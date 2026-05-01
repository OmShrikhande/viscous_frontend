import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viscous_frontend/main.dart';

void main() {
  testWidgets('shows OTP login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BusTrackerApp()));
    expect(find.text('Track Your Child\'s Bus'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
