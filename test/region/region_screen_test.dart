import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_repository.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/region/region_screen.dart';

class FakeRegion implements RegionRepository {
  RegionProfile? profile;
  @override
  Future<RegionProfile?> load() async => profile;
  @override
  Future<void> save(RegionProfile p) async {
    profile = p;
  }

  @override
  Future<ZipRegion> resolve(String zip) async =>
      ZipRegion(zip, 'Shepherdsville', 'KY');
  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async => [
    const StoreLocation('kroger', '123', 'Nearby Kroger', '1 Main', 'KY'),
  ];
  @override
  Future<List<ProductOffer>> search(String id, String query) async => [
    ProductOffer(
      'a',
      'Small chicken',
      price: 4,
      amount: 1,
      unit: 'lb',
      storeId: id,
    ),
    ProductOffer(
      'b',
      'Large chicken',
      price: 6,
      amount: 3,
      unit: 'lb',
      storeId: id,
    ),
  ];
}

void main() {
  Future<FakeRegion> mount(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = FakeRegion();
    await t.pumpWidget(
      ProviderScope(
        overrides: [regionRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RegionScreen()),
      ),
    );
    await t.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'ZIP validation preserves invalid text and saves leading zeroes',
    (t) async {
      final repo = await mount(t, const Size(390, 844));
      await t.enterText(find.byKey(const Key('region-zip')), '1234');
      await t.tap(find.text('Save location'));
      await t.pumpAndSettle();
      expect(repo.profile, isNull);
      expect(find.textContaining('five-digit'), findsOneWidget);
      await t.enterText(find.byKey(const Key('region-zip')), '00501');
      await t.tap(find.text('Save location'));
      await t.pumpAndSettle();
      expect(repo.profile?.zip, '00501');
      expect(find.textContaining('Walmart'), findsOneWidget);
      expect(find.textContaining('Amazon'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('discover select and compare prices at a specific store', (
    t,
  ) async {
    final repo = await mount(t, const Size(1280, 800));
    await t.enterText(find.byKey(const Key('region-zip')), '40165');
    await t.tap(find.text('Save location'));
    await t.pumpAndSettle();
    await t.tap(find.text('Find nearby stores'));
    await t.pumpAndSettle();
    expect(find.textContaining('Shepherdsville'), findsOneWidget);
    await t.tap(find.text('Nearby Kroger'));
    await t.pumpAndSettle();
    expect(repo.profile?.selectedStoreId, '123');
    await t.enterText(find.byKey(const Key('product-query')), 'chicken');
    await t.ensureVisible(find.text('Search products'));
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    expect(find.text('Small chicken'), findsOneWidget);
    expect(find.text('Large chicken'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
