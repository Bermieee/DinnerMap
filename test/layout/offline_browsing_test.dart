import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinnermap/features/sync/shared_cache.dart';
import 'package:dinnermap/features/sync/shared_planner_controller.dart';
import 'package:dinnermap/features/sync/shared_models.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import '../sync/shared_controller_test.dart' show MemoryShared, tick;
import 'layout_test_support.dart';

void main() {
  testWidgets('offline grocery controls allow browsing and block every write', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MemoryShared();
    final today = dateOnly(DateTime.now());
    repo.current = SharedView(
      repo.current.snapshot.copyWith(
        entries: [PlanEntry(id: 'd', date: today, recipeId: 'r')],
        list: SavedShoppingList(
          start: today,
          weeks: 1,
          sourceRevision: 0,
          rows: const [
            ShoppingRow(
              key: 'chicken|count',
              name: 'chicken',
              unit: 'count',
              quantity: 2,
            ),
          ],
          manualItems: const [
            ManualItem(id: 'm', name: 'Milk', amount: '1 gallon'),
          ],
        ),
      ),
      repo.current.revisions,
    );
    final c = SharedPlannerController(
      repo,
      SharedCache(await SharedPreferences.getInstance()),
      'u',
      'h',
    );
    await tester.runAsync(tick);
    repo.events.add(false);
    await tester.runAsync(tick);
    await mountLayout(tester, const Size(390, 844), controller: c);
    await tester.scrollUntilVisible(
      find.text('Takeout'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('planner-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Takeout'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .onChanged,
      isNull,
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await navigate(tester, 'Shopping');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Generate list'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Ounces'));
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('shopping-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Add item'),
      180,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add item'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Copy list'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.text('Set weight estimate'),
      180,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Set weight estimate'),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(find.text('Milk'), 180, scrollable: scroll);
    await tester.pumpAndSettle();
    for (final checkbox in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(checkbox.onChanged, isNull);
    }
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Remove manual item'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(repo.requests, isEmpty);
    expect(repo.generationRequests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'offline shared recipes can search while mutations are disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MemoryShared();
      final c = SharedPlannerController(
        repo,
        SharedCache(await SharedPreferences.getInstance()),
        'u',
        'h',
      );
      await tester.runAsync(tick);
      repo.events.add(false);
      await tester.runAsync(tick);
      await mountLayout(tester, const Size(390, 844), controller: c);
      await navigate(tester, 'Recipes');
      await tester.enterText(find.byType(TextField), 'Soup');
      await tester.pumpAndSettle();
      final add = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add recipe'),
      );
      expect(add.onPressed, isNull);
      final soup = find.widgetWithText(Card, 'Soup');
      await tester.scrollUntilVisible(
        soup,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('recipes-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(soup, findsOneWidget);
      await tester.tap(soup);
      await tester.pumpAndSettle();
      expect(find.text('Ingredients'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Edit recipe'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
