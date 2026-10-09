import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/shared_cache.dart';
import 'account_controller.dart';
import 'account_models.dart';
import 'account_repository.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences not configured'),
);
final accountRepositoryProvider = Provider<AccountRepository?>((ref) => null);
final accountControllerProvider = Provider<AccountController?>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  if (repository == null) return null;
  final controller = AccountController(repository);
  String? previous = controller.state.session?.userId;
  final subscription = controller.changes.listen((s) {
    final current = s.session?.userId;
    if (previous != null && previous != current) {
      SharedCache(ref.read(preferencesProvider)).clearUser(previous!);
    }
    previous = current;
  });
  ref.onDispose(() {
    subscription.cancel();
    controller.dispose();
  });
  return controller;
});
final accountStateProvider = StreamProvider<AccountState>((ref) {
  final c = ref.watch(accountControllerProvider);
  return c == null ? Stream.value(const AccountState()) : c.changes;
});
final useSharedProvider = StateProvider<bool>((ref) => false);
final activeHouseholdProvider =
    Provider<({String userId, String householdId})?>((ref) {
      if (!ref.watch(useSharedProvider)) return null;
      final controller = ref.watch(accountControllerProvider);
      final state =
          ref.watch(accountStateProvider).asData?.value ?? controller?.state;
      if (state?.session?.verified != true || state?.household == null)
        return null;
      return (userId: state!.session!.userId, householdId: state.household!.id);
    });
