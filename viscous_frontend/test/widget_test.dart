import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viscous_frontend/main.dart';

void main() {
  testWidgets('shows phone login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BusTrackerApp()));
    expect(find.text('VISCOUS'), findsOneWidget);
    expect(find.text('SECURE LOGIN'), findsOneWidget);
    expect(find.text('PHONE NUMBER'), findsOneWidget);
    expect(find.text('Enter your registered phone number'), findsOneWidget);
  });
}

