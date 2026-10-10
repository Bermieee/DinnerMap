import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../household/account_providers.dart';
import '../household/supabase_account_repository.dart';
import 'region_repository.dart';
import 'region_controller.dart';
import 'local_region_repository.dart';
import 'supabase_region_repository.dart';

final regionRepositoryProvider = Provider<RegionRepository>((ref) {
  final account = ref.watch(accountControllerProvider);
  final session =
      ref.watch(accountStateProvider).asData?.value.session ??
      account?.state.session;
  final repository = ref.watch(accountRepositoryProvider);
  if (session?.verified == true && repository is SupabaseAccountRepository) {
    return SupabaseRegionRepository(repository.client, session!.userId);
  }
  return LocalRegionRepository(ref.watch(preferencesProvider));
});
final regionControllerProvider = Provider.autoDispose<RegionController>((ref) {
  final controller = RegionController(ref.watch(regionRepositoryProvider));
  ref.onDispose(controller.dispose);
  controller.load();
  return controller;
});
