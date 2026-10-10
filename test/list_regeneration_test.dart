import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/features/shopping/shopping_models.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'package:dinnermap/features/shopping/shopping_export.dart';
import 'package:dinnermap/features/retailers/retailer_adapter.dart';

void main() {
  test('regeneration preserves manual rows and matching checkoffs', () {
    const row = ShoppingRow(
      key: 'egg|count',
      name: 'egg',
      unit: 'count',
      quantity: 4,
    );
    final list = SavedShoppingList(
      start: DateTime(2026),
      weeks: 1,
      sourceRevision: 1,
      rows: [row],
      checked: {row.key, 'manual'},
      manualItems: [const ManualItem(id: 'manual', name: 'soap')],
    );
    final regenerated = regenerateList(
      list,
      const ShoppingResult([row], []),
      2,
    );
    expect(regenerated.checked, {row.key, 'manual'});
    expect(regenerated.manualItems.single.name, 'soap');
    expect(regenerated.sourceRevision, 2);
  });
  test('CSV quotes embedded quotes, commas and newlines', () {
    final list = SavedShoppingList(
      start: DateTime(2026),
      weeks: 1,
      sourceRevision: 0,
      manualItems: [
        const ManualItem(
          id: 'a',
          name: 'oil, "light"\nextra',
          amount: '1 bottle',
        ),
      ],
    );
    expect(shoppingCsv(list), contains('"oil, ""light""\nextra"'));
  });
  test('unknown offers sort last in either direction', () {
    const offers = [
      RetailerOffer(id: 'a', name: 'a', price: 5),
      RetailerOffer(id: 'b', name: 'b'),
      RetailerOffer(id: 'c', name: 'c', price: 2),
    ];
    expect(sortOffers(offers, false).map((o) => o.id), ['c', 'a', 'b']);
    expect(sortOffers(offers, true).map((o) => o.id), ['a', 'c', 'b']);
  });
}
