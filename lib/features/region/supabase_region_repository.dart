import 'package:supabase_flutter/supabase_flutter.dart';
import 'region_models.dart';
import 'region_repository.dart';

class SupabaseRegionRepository implements RegionRepository {
  final SupabaseClient client;
  final String userId;
  SupabaseRegionRepository(this.client, this.userId);
  void _checkUser() {
    final user = client.auth.currentUser;
    if (user?.id != userId || user?.emailConfirmedAt == null)
      throw StateError('Account changed. Sign in again.');
  }

  @override
  Future<RegionProfile?> load() async {
    _checkUser();
    final row = await client
        .from('region_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    _checkUser();
    return row == null ? null : RegionProfile.fromJson(row);
  }

  @override
  Future<void> save(RegionProfile profile) async {
    _checkUser();
    await client.from('region_profiles').upsert({
      'user_id': userId,
      ...profile.toJson(),
    });
    _checkUser();
  }

  Future<dynamic> _invoke(String action, Map<String, dynamic> args) async {
    _checkUser();
    try {
      final response = await client.functions.invoke(
        'retailers',
        body: {'action': action, ...args},
      );
      _checkUser();
      final result = response.data as Map;
      if (response.status != 200 || result['error'] != null)
        throw StateError(
          result['error'] as String? ?? 'Store service is unavailable.',
        );
      return result['data'];
    } on FunctionException catch (e) {
      final details = e.details;
      throw StateError(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Store service is unavailable. Check connection and retry.',
      );
    }
  }

  @override
  Future<ZipRegion> resolve(String zip) async {
    final data = await _invoke('region', {'zip': zip}) as Map;
    return ZipRegion(
      data['zip'] as String,
      data['city'] as String,
      data['state'] as String,
    );
  }

  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async {
    final rows =
        await _invoke('stores', {'zip': zip, 'radius': radius}) as List;
    return rows
        .map(
          (r) => StoreLocation(
            r['retailer'] as String,
            r['id'] as String,
            r['name'] as String,
            r['address'] as String,
            r['state'] as String,
            chain: r['chain'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<List<ProductOffer>> search(String storeId, String query) async {
    final rows =
        await _invoke('products', {'storeId': storeId, 'query': query}) as List;
    return rows
        .map(
          (r) => ProductOffer(
            r['id'] as String,
            r['name'] as String,
            price: (r['price'] as num?)?.toDouble(),
            amount: (r['amount'] as num?)?.toDouble(),
            unit: r['unit'] as String?,
            size: r['size'] as String? ?? '',
            availability: r['availability'] as String? ?? 'Unknown',
            storeId: r['store_id'] as String,
            soldBy: r['sold_by'] as String? ?? 'UNKNOWN',
            retrievedAt: DateTime.tryParse(r['retrieved_at'] as String? ?? ''),
          ),
        )
        .toList();
  }
}
