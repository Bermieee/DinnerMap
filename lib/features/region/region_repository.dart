import 'region_models.dart';

abstract class RegionRepository {
  Future<RegionProfile?> load();
  Future<void> save(RegionProfile profile);
  Future<ZipRegion> resolve(String zip);
  Future<List<StoreLocation>> stores(String zip, int radius);
  Future<List<ProductOffer>> search(String storeId, String query);
}
