import 'dart:async';
import '../lib/features/region/region_models.dart';
import '../lib/features/region/region_repository.dart';
import '../lib/features/region/region_controller.dart';

void check(bool value, String name) {
  if (!value) throw StateError('FAIL $name');
  print('PASS $name');
}

class MemoryRegion implements RegionRepository {
  RegionProfile? saved;
  Completer<ZipRegion>? pending;
  @override
  Future<RegionProfile?> load() async => saved;
  @override
  Future<void> save(RegionProfile profile) async {
    saved = profile;
  }

  @override
  Future<ZipRegion> resolve(String zip) async => pending == null
      ? ZipRegion(zip, 'Shepherdsville', 'KY')
      : pending!.future;
  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async => [
    StoreLocation('kroger', '123', 'Kroger', '123 Main', 'KY'),
  ];
  @override
  Future<List<ProductOffer>> search(String storeId, String query) async => [];
}

Future<void> main() async {
  check(RegionProfile('00501').zip == '00501', 'ZIP leading zeroes preserved');
  for (final zip in ['4016', 'ABCDE', '40165-0001', '']) {
    bool rejected = false;
    try {
      RegionProfile(zip);
    } catch (_) {
      rejected = true;
    }
    check(rejected, 'reject ZIP $zip');
  }
  for (final radius in [0, 101]) {
    bool rejected = false;
    try {
      RegionProfile('40165', radiusMiles: radius);
    } catch (_) {
      rejected = true;
    }
    check(rejected, 'reject radius $radius');
  }
  final offers = [
    ProductOffer(
      'a',
      'Apple',
      price: 4,
      amount: 16,
      unit: 'oz',
      soldBy: 'UNIT',
    ),
    ProductOffer(
      'b',
      'Banana',
      price: 3,
      amount: 1,
      unit: 'lb',
      soldBy: 'UNIT',
    ),
    ProductOffer('c', 'Unknown'),
    ProductOffer('d', 'Milk', price: 2, amount: 1, unit: 'gal', soldBy: 'UNIT'),
    ProductOffer('e', 'Free', price: 0, amount: 1, unit: 'lb', soldBy: 'UNIT'),
  ];
  check(
    sortProductOffers(offers, OfferSort.packageHigh).last.id == 'c',
    'unknown package price last descending',
  );
  check(
    sortProductOffers(offers, OfferSort.packageLow).first.id == 'e',
    'zero is known price',
  );
  check(
    offers[0].unitPrice == 4 && offers[1].unitPrice == 3,
    'mass normalized to pounds',
  );
  check(offers[3].unitLabel == 'per fl oz', 'volume is separate family');
  final mass = sortProductOffers(offers, OfferSort.unitLow, unitFamily: 'mass');
  check(
    mass.first.id == 'e' &&
        mass.indexWhere((o) => o.id == 'd') >
            mass.indexWhere((o) => o.id == 'a'),
    'incompatible units excluded from ranking',
  );
  final repo = MemoryRegion();
  final c = RegionController(repo);
  await c.load();
  await c.saveProfile('40165', 25);
  await c.discover();
  await c.selectStore(c.state.stores.first);
  check(c.state.profile!.selectedStoreId == '123', 'selected store saved');
  await c.search('rice');
  check(
    c.state.searchedQuery == 'rice' && c.state.offers.isEmpty,
    'completed empty search identified',
  );
  await c.saveProfile('00501', 25);
  check(
    c.state.profile!.selectedStoreId == null && c.state.stores.isEmpty,
    'ZIP change clears stores',
  );
  repo.pending = Completer<ZipRegion>();
  final late = c.discover();
  c.dispose();
  repo.pending!.complete(ZipRegion('00501', 'Holtsville', 'NY'));
  await late;
  check(c.state.region == null, 'disposed context drops late response');
}
