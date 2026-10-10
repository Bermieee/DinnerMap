import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_repository.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_price_screen.dart';

class PriceRepository implements RegionRepository {
  bool fail = false;
  String basis = 'UNIT';
  @override
  Future<RegionProfile?> load() async =>
      RegionProfile('40165', selectedStoreId: '123');
  @override
  Future<void> save(RegionProfile p) async {}
  @override
  Future<ZipRegion> resolve(String zip) async => ZipRegion(zip, 'City', 'KY');
  @override
  Future<List<StoreLocation>> stores(String zip, int radius) async => [];
  @override
  Future<List<ProductOffer>> search(String id, String query) async {
    if (fail) throw StateError('Kroger connection is not configured.');
    return [
      ProductOffer(
        'p',
        'Two-pound chicken',
        price: 4.99,
        amount: 2,
        unit: 'lb',
        storeId: id,
        soldBy: basis,
      ),
    ];
  }
}

void main() {
  SavedShoppingList list(double quantity) => SavedShoppingList(
    start: DateTime(2026, 10, 10),
    weeks: 1,
    sourceRevision: 1,
    rows: [
      ShoppingRow(
        key: 'chicken|mass',
        name: 'chicken',
        quantity: quantity,
        unit: 'lb',
      ),
    ],
  );
  Future<void> mount(
    WidgetTester t,
    PriceRepository repo,
    double quantity,
  ) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      ProviderScope(
        overrides: [regionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: ShoppingPricePanel(repository: repo, list: list(quantity)),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'reviewed packages produce a partial total and changed quantity invalidates it',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = PriceRepository();
      await mount(t, repo, 5);
      await t.tap(find.text('Find Kroger product'));
      await t.pumpAndSettle();
      await t.tap(find.text('Search products'));
      await t.pumpAndSettle();
      await t.tap(find.text('Two-pound chicken'));
      await t.pumpAndSettle();
      expect(find.text('Line estimate: \$14.97'), findsOneWidget);
      await t.tap(find.text('Use product estimate'));
      await t.pumpAndSettle();
      expect(find.text('Estimated list total: \$14.97'), findsOneWidget);
      expect(find.text('1 of 1 items priced'), findsOneWidget);
      await mount(t, repo, 7);
      expect(find.text('Estimated list total: —'), findsOneWidget);
      expect(find.text('0 of 1 items priced'), findsOneWidget);
      await mount(t, repo, 5);
      expect(find.text('Estimated list total: —'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('missing credentials leaves the list unpriced', (t) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = PriceRepository()..fail = true;
    await mount(t, repo, 5);
    await t.tap(find.text('Find Kroger product'));
    await t.pumpAndSettle();
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    expect(find.textContaining('not configured'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use product estimate'),
          )
          .onPressed,
      isNull,
    );
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Estimated list total: —'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('unknown price basis needs explicit package confirmation', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = PriceRepository()..basis = 'UNKNOWN';
    await mount(t, repo, 5);
    await t.tap(find.text('Find Kroger product'));
    await t.pumpAndSettle();
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    await t.tap(find.text('Two-pound chicken'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Packages to buy (1–999)'),
      '3',
    );
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use product estimate'),
          )
          .onPressed,
      isNull,
    );
    await t.tap(find.byType(CheckboxListTile));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use product estimate'),
          )
          .onPressed,
      isNotNull,
    );
    expect(t.takeException(), isNull);
  });
}
