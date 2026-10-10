import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/features/household/account_models.dart';
import 'package:dinnermap/features/household/account_controller.dart';
import 'package:dinnermap/features/household/account_repository.dart';
import 'dart:async';
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
        MaterialApp(
          home: Scaffold(
            body: HouseholdScreen(
              controller: AccountController(TestAccounts()),
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

class TestAccounts implements AccountRepository {
  @override
  AccountSession? get currentSession => null;
  @override
  Stream<AccountSession?> watchSession() => const Stream.empty();
  @override
  Future<AccountSession?> refreshSession() async => null;
  @override
  Future<Household?> currentHousehold() async => null;
  @override
  Future<List<HouseholdMember>> members() async => [];
  @override
  Future<void> signUp(String e, String p) async {}
  @override
  Future<void> signIn(String e, String p) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> resetPassword(String e) async {}
  @override
  Future<void> updatePassword(String p) async {}
  @override
  Future<Household> createHousehold(String n) async => Household('h', n);
  @override
  Future<Household> redeemInvitation(String t) async =>
      const Household('h', 'Family');
  @override
  Future<String> createInvitation() async => 'token';
  @override
  Future<void> leaveHousehold() async {}
}
