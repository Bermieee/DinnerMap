import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_pricing.dart';
import 'package:dinnermap/features/shopping/shopping_quote_provider.dart';
import 'package:dinnermap/features/shopping/shopping_screen.dart';
import 'widget_test.dart' show MemoryRepository;

class LoadedPlanner extends PlannerController {
  LoadedPlanner(super.repository, PlannerSnapshot snapshot)
    : super(autoLoad: false) {
    state = AsyncValue.data(snapshot);
  }
}

void main() {
  const flour = ShoppingRow(
    key: 'flour',
    name: 'all-purpose flour',
    quantity: 78.8627455,
    unit: 'ml',
  );
  final list = SavedShoppingList(
    start: DateTime(2026, 10, 10),
    weeks: 1,
    sourceRevision: 1,
    rows: [flour],
  );
  final selected = PriceSelection(
    row: flour,
    offer: const ProductOffer(
      'bag',
      'Flour bag',
      amount: 5,
      unit: 'lb',
      size: '5 lb',
      price: 3,
      storeId: '123',
      soldBy: 'UNIT',
    ),
    packages: 1,
  );
  test(
    'session discards changed amounts permanently and clears on store change',
    () {
      final session = QuoteSession()
        ..selectStore('123')
        ..select(selected);
      session.reconcile(list);
      expect(session.state.selections, isNotEmpty);
      session.reconcile(
        SavedShoppingList(
          start: list.start,
          weeks: 1,
          sourceRevision: 1,
          rows: [
            const ShoppingRow(
              key: 'flour',
              name: 'all-purpose flour',
              quantity: 500,
              unit: 'ml',
            ),
          ],
        ),
      );
      session.reconcile(list);
      expect(session.state.selections, isEmpty);
      session.select(selected);
      session.selectStore('456');
      expect(session.state.selections, isEmpty);
      session.dispose();
    },
  );
  for (final size in [const Size(1280, 1000), const Size(390, 844)]) {
    testWidgets(
      'grocery list shows reviewed purchases and copies them at $size',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final snapshot = PlannerSnapshot(
          entries: const [],
          recipes: const {},
          revision: 1,
          list: list,
        );
        final repository = MemoryRepository(snapshot);
        final planner = LoadedPlanner(repository, snapshot);
        String? copied;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              copied = (call.arguments as Map)['text'] as String;
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repository),
              plannerFactoryProvider.overrideWithValue(() => planner),
            ],
            child: MaterialApp(
              home: Scaffold(body: ShoppingScreen(snapshot: snapshot)),
            ),
          ),
        );
        await t.pumpAndSettle();
        final container = ProviderScope.containerOf(
          t.element(find.byType(ShoppingScreen)),
        );
        container.read(shoppingQuoteProvider.notifier)
          ..selectStore('123')
          ..select(selected);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Buy 1 × 5 lb'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Needed for recipes: 1/3 cup'), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Copy list'),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.text('Copy list'));
        await t.pumpAndSettle();
        expect(copied, contains('Buy 1 × 5 lb'));
        expect(copied, contains('1/3 cup'));
        container.read(regionalStoreProvider.notifier).state = '456';
        await t.pumpAndSettle();
        expect(container.read(shoppingQuoteProvider).selections, isEmpty);
        expect(t.takeException(), isNull);
      },
    );
  }
}
