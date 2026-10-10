import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../household/account_providers.dart';
import '../household/supabase_account_repository.dart';
import 'region_repository.dart';
import 'region_controller.dart';
import 'local_region_repository.dart';
import 'supabase_region_repository.dart';

final regionalIdentityProvider = Provider<({String? userId, bool verified})>((
  ref,
) {
  final controller = ref.watch(accountControllerProvider);
  final state =
      ref.watch(accountStateProvider).asData?.value ?? controller?.state;
  return (
    userId: state?.session?.userId,
    verified: state?.session?.verified ?? false,
  );
});
final regionRepositoryProvider = Provider<RegionRepository>((ref) {
  final identity = ref.watch(regionalIdentityProvider);
  final repository = ref.watch(accountRepositoryProvider);
  if (identity.verified && repository is SupabaseAccountRepository) {
    return SupabaseRegionRepository(repository.client, identity.userId!);
  }
  return LocalRegionRepository(ref.watch(preferencesProvider));
});
final regionControllerProvider = Provider.autoDispose<RegionController>((ref) {
  final controller = RegionController(ref.watch(regionRepositoryProvider));
  ref.onDispose(controller.dispose);
  controller.load();
  return controller;
});
