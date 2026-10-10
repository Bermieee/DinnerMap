import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_repository.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/region/region_screen.dart';

class FakeRegion implements RegionRepository {
  RegionProfile? profile;
  bool empty = false;
  Completer<ZipRegion>? pending;
  @override
  Future<RegionProfile?> load() async => profile;
  @override
  Future<void> save(RegionProfile p) async {
    profile = p;
  }

  @override
  Future<ZipRegion> resolve(String zip) async => pending == null
      ? ZipRegion(zip, 'Shepherdsville', 'KY')
      : pending!.future;
  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async => [
    const StoreLocation('kroger', '123', 'Nearby Kroger', '1 Main', 'KY'),
  ];
  @override
  Future<List<ProductOffer>> search(String id, String query) async => empty
      ? []
      : [
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

Future<void> reveal(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target,
    150,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('region-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.pumpAndSettle();
}

void main() {
  Future<FakeRegion> mount(
    WidgetTester t,
    Size size, {
    double scale = 1,
    List<DisplayFeature> features = const [],
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = FakeRegion();
    await t.pumpWidget(
      ProviderScope(
        overrides: [regionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              displayFeatures: features,
            ),
            child: child!,
          ),
          home: const RegionScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'ZIP validation preserves invalid text and saves leading zeroes',
    (t) async {
      final repo = await mount(t, const Size(390, 844));
      await reveal(t, find.byKey(const Key('region-zip')));
      await t.enterText(find.byKey(const Key('region-zip')), '1234');
      await t.tap(find.text('Save location'));
      await t.pumpAndSettle();
      expect(repo.profile, isNull);
      expect(find.textContaining('five-digit'), findsOneWidget);
      await reveal(t, find.byKey(const Key('region-zip')));
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
    await reveal(t, find.byKey(const Key('region-zip')));
    await t.enterText(find.byKey(const Key('region-zip')), '40165');
    await t.tap(find.text('Save location'));
    await t.pumpAndSettle();
    await t.tap(find.text('Find nearby stores'));
    await t.pumpAndSettle();
    expect(find.textContaining('Shepherdsville'), findsOneWidget);
    await t.tap(find.text('Nearby Kroger'));
    await t.pumpAndSettle();
    expect(repo.profile?.selectedStoreId, '123');
    await reveal(t, find.byKey(const Key('product-query')));
    await t.enterText(find.byKey(const Key('product-query')), 'chicken');
    await reveal(t, find.text('Search products'));
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Small chicken'));
    expect(find.text('Small chicken'), findsOneWidget);
    await reveal(t, find.text('Large chicken'));
    expect(find.text('Large chicken'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('empty product search explains there are no results', (t) async {
    final repo = await mount(t, const Size(1280, 800));
    repo.empty = true;
    await reveal(t, find.byKey(const Key('region-zip')));
    await t.enterText(find.byKey(const Key('region-zip')), '40165');
    await t.tap(find.text('Save location'));
    await t.pumpAndSettle();
    await t.tap(find.text('Find nearby stores'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nearby Kroger'));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const Key('product-query')));
    await t.enterText(find.byKey(const Key('product-query')), 'rice');
    await reveal(t, find.text('Search products'));
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    await reveal(t, find.textContaining('No products returned'));
    expect(find.textContaining('No products returned'), findsOneWidget);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(800, 1280),
  ]) {
    testWidgets('regional form reaches save at $size with large text', (
      t,
    ) async {
      final repo = await mount(t, size, scale: 2);
      await reveal(t, find.byKey(const Key('region-zip')));
      await t.enterText(find.byKey(const Key('region-zip')), '40165');
      await reveal(t, find.text('Save location'));
      await t.tap(find.text('Save location'));
      await t.pumpAndSettle();
      expect(repo.profile?.zip, '40165');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'store page selects larger lower fold region for its header and form',
    (t) async {
      await mount(
        t,
        const Size(800, 800),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 300, 800, 24),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      expect(
        t.getRect(find.text('Stores & prices')).top,
        greaterThanOrEqualTo(324),
      );
      expect(
        t.getRect(find.byKey(const Key('region-zip'))).top,
        greaterThanOrEqualTo(324),
      );
      expect(t.takeException(), isNull);
    },
  );
}
