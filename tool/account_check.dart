import 'dart:async';
import '../lib/features/household/account_controller.dart';
import '../lib/features/household/account_repository.dart';
import '../lib/features/household/account_models.dart';

class FakeAccounts implements AccountRepository {
  final sessions = StreamController<AccountSession?>.broadcast();
  Completer<Household?>? delayed;
  AccountSession? session;
  @override
  AccountSession? get currentSession => session;
  @override
  Stream<AccountSession?> watchSession() => sessions.stream;
  void emit(AccountSession? s) {
    session = s;
    sessions.add(s);
  }

  @override
  Future<Household?> currentHousehold() async =>
      delayed == null ? const Household('h', 'Family') : delayed!.future;
  @override
  Future<AccountSession?> refreshSession() async => session;
  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<void> signUp(String e, String p) async {}
  @override
  Future<void> signIn(String e, String p) async {}
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
  Future<String> createInvitation() async => 'invite';
  @override
  Future<List<HouseholdMember>> members() async => [];
  @override
  Future<void> leaveHousehold() async {}
}

Future<void> tick() async => Future<void>.delayed(Duration.zero);
void check(bool v, String name) {
  if (!v) throw StateError(name);
  print('PASS $name');
}

Future<void> main() async {
  final repo = FakeAccounts();
  final c = AccountController(repo);
  repo.emit(const AccountSession('u', 'test@example.com', false));
  await tick();
  await c.createHousehold('Family');
  check(
    c.state.error != null && c.state.household == null,
    'unverified cannot create',
  );
  repo.delayed = Completer<Household?>();
  repo.emit(const AccountSession('u', 'test@example.com', true));
  await tick();
  repo.emit(null);
  await tick();
  repo.delayed!.complete(const Household('h', 'Late'));
  await tick();
  check(
    c.state.session == null && c.state.household == null,
    'late context ignored after sign out',
  );
  repo.delayed = null;
  repo.emit(const AccountSession('u', 'test@example.com', true));
  await tick();
  check(c.state.household?.name == 'Family', 'verified context loaded');
  await c.signOut();
  await tick();
  check(c.state.session == null, 'signed out state cleared');
  await c.signIn('bad', '');
  check(c.state.error != null, 'invalid credentials blocked');
  c.dispose();
  await repo.sessions.close();
}
