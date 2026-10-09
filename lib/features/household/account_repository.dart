import 'account_models.dart';

abstract class AccountRepository {
  AccountSession? get currentSession;
  Stream<AccountSession?> watchSession();
  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String password);
  Future<Household?> currentHousehold();
  Future<Household> createHousehold(String name);
  Future<Household> redeemInvitation(String token);
  Future<String> createInvitation();
  Future<List<HouseholdMember>> members();
  Future<void> leaveHousehold();
}
