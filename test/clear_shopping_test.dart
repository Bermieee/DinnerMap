import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'package:dinnermap/features/shopping/shopping_screen.dart';
import 'package:dinnermap/features/shopping/shopping_quote_provider.dart';
import 'package:dinnermap/features/shopping/shopping_pricing.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/sync/shared_models.dart';
import 'consumer_shopping_test.dart' show LoadedPlanner;
import 'widget_test.dart' show MemoryRepository;

void main() {
  testWidgets(
    'clear removes saved grocery list and quotes and displays shopping name',
    (t) async {
      t.view.physicalSize = const Size(1280, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const row = ShoppingRow(
        key: 'chicken',
        name: 'boneless chicken breasts, cubed',
        quantity: 2,
        unit: 'lb',
      );
      final list = SavedShoppingList(
        start: DateTime(2026, 10, 10),
        weeks: 1,
        sourceRevision: 0,
        rows: [row],
        checked: {'chicken'},
        manualItems: [const ManualItem(id: 'm', name: 'Milk')],
      );
      final snapshot = PlannerSnapshot(entries: [], recipes: {}, list: list);
      final repo = MemoryRepository(snapshot);
      final planner = LoadedPlanner(repo, snapshot);
      final session = QuoteSession()
        ..selectStore('123')
        ..select(
          PriceSelection(
            row: row,
            offer: const ProductOffer(
              'p',
              'Chicken',
              price: 4,
              amount: 2,
              unit: 'lb',
              storeId: '123',
              soldBy: 'UNIT',
            ),
            packages: 1,
          ),
        );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            plannerProvider.overrideWith((ref) => planner),
            shoppingQuoteProvider.overrideWith((ref) => session),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: ShoppingScreen(
                  snapshot: ref.watch(plannerProvider).asData!.value,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('boneless chicken breasts'), findsOneWidget);
      expect(find.text('boneless chicken breasts, cubed'), findsNothing);
      await t.tap(find.text('Clear grocery list'));
      await t.pumpAndSettle();
      expect(planner.state.asData!.value.list, isNull);
      expect(repo.snapshot.list, isNull);
      expect(session.state.selections, isEmpty);
      expect(
        find.text('Choose your dates and generate a grocery list.'),
        findsOneWidget,
      );
      expect(repo.snapshot.entries, snapshot.entries);
      expect(repo.snapshot.recipes, snapshot.recipes);
      expect(PlannerSnapshot.decode(repo.snapshot.encode()).list, isNull);
      final commands = changesBetween(
        SharedView(snapshot, {}),
        snapshot.copyWith(clearList: true),
      );
      expect(commands.single['op'], 'clearList');
      expect(commands.single['value'], list.toJson());
      expect(t.takeException(), isNull);
    },
  );
}
