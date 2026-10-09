import 'package:shared_preferences/shared_preferences.dart';
import 'shared_models.dart';

class SharedCache {
  final SharedPreferences preferences;
  SharedCache(this.preferences);
  String key(String user, String household) =>
      'dinnermap.shared.$user.$household';
  SharedView? read(String user, String household) {
    final raw = preferences.getString(key(user, household));
    if (raw == null) return null;
    try {
      return SharedView.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String user, String household, SharedView view) async {
    await preferences.setString(key(user, household), view.encode());
  }

  Future<void> clearUser(String user) async {
    for (final k
        in preferences
            .getKeys()
            .where((k) => k.startsWith('dinnermap.shared.$user.'))
            .toList()) {
      await preferences.remove(k);
    }
  }
}
