import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_price_screen.dart';
import 'shopping_pricing_test.dart' show PriceRepository;

class AutoRepository extends PriceRepository {
  Completer<List<ProductOffer>>? pending;
  int searches = 0;
  @override
  Future<List<ProductOffer>> search(String id, String query) async {
    searches++;
    if (pending != null) return pending!.future;
    return [
      ProductOffer(
        'p',
        'Chicken',
        price: 4.99,
        amount: 2,
        unit: 'lb',
        size: '2 lb',
        storeId: id,
        soldBy: 'UNIT',
      ),
    ];
  }
}

void main() {
  SavedShoppingList list(double q) => SavedShoppingList(
    start: DateTime(2026, 10, 10),
    weeks: 1,
    sourceRevision: 1,
    rows: [
      ShoppingRow(key: 'chicken', name: 'chicken', unit: 'lb', quantity: q),
    ],
  );
  Future<void> mount(WidgetTester t, AutoRepository repo, double q) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          regionRepositoryProvider.overrideWithValue(repo),
          repo.quoteOverride,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ShoppingPricePanel(repository: repo, list: list(q)),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'automatic search stages a priced suggestion for explicit review',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = AutoRepository();
      await mount(t, repo, 3);
      await t.tap(find.text('Find best deals at Kroger'));
      await t.pumpAndSettle();
      expect(repo.searches, 1);
      expect(find.text('Suggested: Chicken'), findsOneWidget);
      expect(find.text('0 of 1 items priced'), findsOneWidget);
      await t.tap(find.text('Accept reviewed suggestions'));
      await t.pumpAndSettle();
      expect(find.text('Estimated list total: \$9.98'), findsOneWidget);
      expect(find.text('1 of 1 items priced'), findsOneWidget);
      await t.tap(find.text('Find best deals at Kroger'));
      await t.pumpAndSettle();
      expect(repo.searches, 1);
      expect(find.text('Estimated list total: \$9.98'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('changed quantity rejects a late whole-list search result', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = AutoRepository()..pending = Completer();
    await mount(t, repo, 3);
    await t.tap(find.text('Find best deals at Kroger'));
    await t.pump();
    await mount(t, repo, 7);
    repo.pending!.complete([
      const ProductOffer(
        'p',
        'Chicken',
        price: 4,
        amount: 2,
        unit: 'lb',
        storeId: '123',
        soldBy: 'UNIT',
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.textContaining('Suggested:'), findsNothing);
    expect(find.text('0 of 1 items priced'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('stop search rejects pending products', (t) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = AutoRepository()..pending = Completer();
    await mount(t, repo, 3);
    await t.tap(find.text('Find best deals at Kroger'));
    await t.pump();
    await t.tap(find.text('Stop search'));
    await t.pump();
    repo.pending!.complete([
      const ProductOffer(
        'p',
        'Chicken',
        price: 4,
        amount: 2,
        unit: 'lb',
        storeId: '123',
        soldBy: 'UNIT',
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.textContaining('Suggested:'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
