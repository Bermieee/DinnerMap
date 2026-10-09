import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_planner_repository.dart';
import 'features/planner/planner_controller.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          LocalPlannerRepository(preferences),
        ),
      ],
      child: const DinnerMapApp(),
    ),
  );
}
