import 'dart:async';
import 'account_models.dart';
import 'account_repository.dart';

class AccountController {
  final AccountRepository repository;
  final _changes = StreamController<AccountState>.broadcast(sync: true);
  late final StreamSubscription<AccountSession?> _subscription;
  AccountState state = const AccountState();
  int _generation = 0;
  bool _disposed = false, _operation = false;
  Stream<AccountState> get changes => _changes.stream;
  AccountController(this.repository) {
    _subscription = repository.watchSession().listen(
      _session,
      onError: (Object e) {
        _set(
          AccountState(
            error: 'Account connection failed. Please sign in again.',
          ),
        );
      },
    );
    _session(repository.currentSession);
  }
  void _set(AccountState s) {
    if (!_disposed) {
      state = s;
      _changes.add(s);
    }
  }

  Future<void> _session(AccountSession? s) async {
    final generation = ++_generation;
    _set(AccountState(session: s, busy: s?.verified == true));
    if (s?.verified != true) return;
    try {
      final h = await repository.currentHousehold();
      final members = h == null
          ? <HouseholdMember>[]
          : await repository.members();
      if (generation == _generation)
        _set(AccountState(session: s, household: h, members: members));
    } catch (e) {
      if (generation == _generation)
        _set(
          AccountState(
            session: s,
            error: 'Could not load household. Check your connection and retry.',
          ),
        );
    }
  }

  bool _email(String e) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e.trim());
  Future<void> _run(
    Future<void> Function() fn, {
    bool verified = false,
    String? message,
  }) async {
    if (_operation || _disposed) return;
    final before = state;
    if (verified && before.session?.verified != true) {
      _set(
        AccountState(
          session: before.session,
          error: 'Verify your email before using households.',
        ),
      );
      return;
    }
    _operation = true;
    final g = _generation;
    _set(
      AccountState(
        session: before.session,
        household: before.household,
        members: before.members,
        busy: true,
      ),
    );
    try {
      await fn();
      if (g == _generation)
        _set(
          AccountState(
            session: state.session,
            household: state.household,
            members: state.members,
            message: message,
          ),
        );
    } catch (e) {
      if (g == _generation)
        _set(
          AccountState(
            session: state.session,
            household: state.household,
            members: state.members,
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
    } finally {
      _operation = false;
    }
  }

  Future<void> signIn(String e, String p) => _run(() async {
    if (!_email(e) || p.isEmpty)
      throw Exception('Enter an email and password.');
    await repository.signIn(e.trim(), p);
  });
  Future<void> signUp(String e, String p) => _run(() async {
    if (!_email(e) || p.length < 8)
      throw Exception(
        'Enter an email and a password of at least 8 characters.',
      );
    await repository.signUp(e.trim(), p);
  }, message: 'Check your email to verify your account, then sign in.');
  Future<void> resetPassword(String e) => _run(() async {
    if (!_email(e)) throw Exception('Enter your email address.');
    await repository.resetPassword(e.trim());
  }, message: 'If that account exists, a password reset email has been sent.');
  Future<void> updatePassword(String p) => _run(() async {
    if (p.length < 8) throw Exception('Use at least 8 characters.');
    await repository.updatePassword(p);
    await _session(repository.currentSession);
  }, message: 'Password updated.');
  Future<void> signOut() async {
    ++_generation;
    _set(const AccountState(busy: true));
    try {
      await repository.signOut();
      _set(const AccountState());
    } catch (e) {
      _set(
        const AccountState(
          error: 'Sign-out could not finish. Retry while online.',
        ),
      );
    }
  }

  Future<void> refresh() async {
    final generation = _generation;
    try {
      final s = await repository.refreshSession();
      if (generation == _generation) await _session(s);
    } catch (_) {
      if (generation == _generation)
        _set(
          AccountState(
            session: state.session,
            household: state.household,
            members: state.members,
            error: 'Could not refresh account. Check your connection.',
          ),
        );
    }
  }

  Future<void> createHousehold(String name) => _run(() async {
    if (name.trim().isEmpty || name.trim().length > 100)
      throw Exception('Use a household name of 1–100 characters.');
    await repository.createHousehold(name.trim());
    await refresh();
  }, verified: true);
  Future<void> redeemInvitation(String token) => _run(() async {
    await repository.redeemInvitation(token.trim());
    await refresh();
  }, verified: true);
  Future<String?> createInvitation() async {
    String? result;
    await _run(() async {
      result = await repository.createInvitation();
    }, verified: true);
    return result;
  }

  Future<void> leaveHousehold() => _run(() async {
    await repository.leaveHousehold();
    await refresh();
  }, verified: true);
  void dispose() {
    _disposed = true;
    ++_generation;
    _subscription.cancel();
    _changes.close();
  }
}
