import 'package:shared_preferences/shared_preferences.dart';

import 'planner_repository.dart';

class LocalPlannerRepository implements PlannerRepository {
  final SharedPreferences preferences;
  LocalPlannerRepository(this.preferences);
  static const key = 'dinnermap.snapshot.v1';
  @override
  Future<PlannerSnapshot?> load() async {
    final raw = preferences.getString(key);
    return raw == null ? null : PlannerSnapshot.decode(raw);
  }

  @override
  Future<void> save(PlannerSnapshot snapshot) async {
    if (!await preferences.setString(key, snapshot.encode()))
      throw StateError('Could not save this plan');
  }

  @override
  Future<String?> rawBackup() async => preferences.getString(key);
}
