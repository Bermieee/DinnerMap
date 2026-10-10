class AccountSession {
  final String userId, email;
  final bool verified, passwordRecovery;
  const AccountSession(
    this.userId,
    this.email,
    this.verified, {
    this.passwordRecovery = false,
  });
}

class Household {
  final String id, name;
  const Household(this.id, this.name);
}

class HouseholdMember {
  final String userId, email;
  const HouseholdMember(this.userId, this.email);
}

class AccountState {
  final AccountSession? session;
  final Household? household;
  final List<HouseholdMember> members;
  final bool busy;
  final String? error, message;
  const AccountState({
    this.session,
    this.household,
    this.members = const [],
    this.busy = false,
    this.error,
    this.message,
  });
}
