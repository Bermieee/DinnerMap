import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_planner_repository.dart';
import 'features/planner/planner_controller.dart';
import 'app.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/household/account_providers.dart';
import 'features/household/supabase_account_repository.dart';
import 'features/sync/shared_cache.dart';
import 'features/sync/shared_planner_controller.dart';
import 'features/sync/supabase_shared_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseAccountRepository? accounts;
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key, debug: false);
    accounts = SupabaseAccountRepository(
      Supabase.instance.client,
      redirectUrl: kIsWeb
          ? Uri.base.replace(query: '', fragment: '').toString()
          : 'com.dinnermap://auth-callback/',
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        accountRepositoryProvider.overrideWithValue(accounts),
        plannerFactoryProvider.overrideWith((ref) {
          final context = ref.watch(activeHouseholdProvider);
          if (context == null || accounts == null) return null;
          return () => SharedPlannerController(
            SupabaseSharedRepository(accounts!.client, context.householdId),
            SharedCache(preferences),
            context.userId,
            context.householdId,
          );
        }),
        repositoryProvider.overrideWithValue(
          LocalPlannerRepository(preferences),
        ),
      ],
      child: const DinnerMapApp(),
    ),
  );
}
