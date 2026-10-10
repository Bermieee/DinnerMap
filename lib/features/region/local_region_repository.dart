import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'region_models.dart';
import 'region_repository.dart';

class LocalRegionRepository implements RegionRepository {
  final SharedPreferences preferences;
  LocalRegionRepository(this.preferences);
  static const key = 'dinnermap.local-region.v1';
  @override
  Future<RegionProfile?> load() async {
    final raw = preferences.getString(key);
    return raw == null
        ? null
        : RegionProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(RegionProfile profile) async {
    if (!await preferences.setString(key, jsonEncode(profile.toJson())))
      throw StateError('Location preferences could not be saved.');
  }

  @override
  Future<ZipRegion> resolve(String zip) async => throw StateError(
    'Sign in with a configured account to discover stores. Your ZIP is saved on this device.',
  );
  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async =>
      throw StateError('Store discovery requires a configured account.');
  @override
  Future<List<ProductOffer>> search(String storeId, String query) async =>
      throw StateError('Live products require a configured account.');
}
