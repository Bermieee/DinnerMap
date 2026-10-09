import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_models.dart';
import 'account_repository.dart';

class SupabaseAccountRepository implements AccountRepository {
  final SupabaseClient client;
  final String redirectUrl;
  bool _recovering = false;
  SupabaseAccountRepository(this.client, {required this.redirectUrl});
  AccountSession? _session(User? u) => u == null
      ? null
      : AccountSession(
          u.id,
          u.email ?? '',
          u.emailConfirmedAt != null,
          passwordRecovery: _recovering,
        );
  @override
  AccountSession? get currentSession => _session(client.auth.currentUser);
  @override
  Stream<AccountSession?> watchSession() =>
      client.auth.onAuthStateChange.map((a) {
        if (a.event == AuthChangeEvent.passwordRecovery) _recovering = true;
        if (a.event == AuthChangeEvent.signedOut) _recovering = false;
        return _session(a.session?.user);
      });
  @override
  Future<AccountSession?> refreshSession() async {
    await client.auth.refreshSession();
    return currentSession;
  }

  @override
  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectUrl,
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    _recovering = false;
  }

  @override
  Future<Household?> currentHousehold() async {
    final rows = await client.from('households').select('id,name');
    return rows.isEmpty
        ? null
        : Household(rows.first['id'] as String, rows.first['name'] as String);
  }

  Future<Household> _requiredHousehold() async =>
      await currentHousehold() ??
      (throw StateError('Household not available. Refresh and try again.'));
  @override
  Future<Household> createHousehold(String name) async {
    await client.rpc('create_household', params: {'p_name': name});
    return _requiredHousehold();
  }

  @override
  Future<Household> redeemInvitation(String token) async {
    await client.rpc('redeem_invitation', params: {'p_token': token});
    return _requiredHousehold();
  }

  @override
  Future<String> createInvitation() async =>
      await client.rpc('create_invitation') as String;
  @override
  Future<List<HouseholdMember>> members() async {
    final rows = await client.rpc('household_members') as List;
    return rows
        .map(
          (r) => HouseholdMember(r['user_id'] as String, r['email'] as String),
        )
        .toList();
  }

  @override
  Future<void> leaveHousehold() async {
    await client.rpc('leave_household');
  }
}
