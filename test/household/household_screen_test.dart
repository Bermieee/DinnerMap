import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/features/household/account_models.dart';
import 'package:dinnermap/features/household/household_screen.dart';

void main() {
  testWidgets('unconfigured accounts retain local mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HouseholdScreen(state: AccountState())),
      ),
    );
    expect(find.textContaining('not configured'), findsOneWidget);
  });
  testWidgets(
    'unverified users see verification rather than household controls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HouseholdScreen(
              state: AccountState(
                session: AccountSession('u', 'a@example.com', false),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Verify'), findsWidgets);
      expect(find.text('Create household'), findsNothing);
    },
  );
}
