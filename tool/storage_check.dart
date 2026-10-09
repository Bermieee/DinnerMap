import '../lib/data/planner_repository.dart';
import '../lib/features/planner/models.dart';
import '../lib/features/shopping/shopping_models.dart';
import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/shopping/shopping_export.dart';
import '../lib/features/retailers/retailer_adapter.dart';

void main() async {
  void check(bool value, String name) {
    if (!value) throw StateError(name);
    print('PASS $name');
  }

  final r = const ShoppingRow(
    key: 'beef|mass',
    name: 'beef',
    unit: 'g',
    quantity: 453.59237,
  );
  final before = SavedShoppingList(
    start: DateTime(2026, 1, 1),
    weeks: 1,
    sourceRevision: 1,
    rows: [r],
    checked: {r.key},
    manualItems: [const ManualItem(id: 'x', name: 'soap')],
  );
  final after = regenerateList(before, ShoppingResult([r], []), 2);
  check(
    after.checked.contains(r.key) && after.manualItems.single.name == 'soap',
    'regeneration preserves checks and manual items',
  );
  check(shoppingCsv(after).contains('beef'), 'CSV includes groceries');
  final snapshot = PlannerSnapshot(
    entries: [],
    recipes: {},
    revision: 2,
    list: after,
  );
  check(
    PlannerSnapshot.decode(snapshot.encode()).list!.checked.contains(r.key),
    'snapshot round trip',
  );
  try {
    PlannerSnapshot.decode('{broken');
    throw StateError('bad JSON accepted');
  } on FormatException {
    print('PASS corrupt data rejected');
  }
  final offers = [
    const RetailerOffer(id: 'a', name: 'a', price: 5),
    const RetailerOffer(id: 'b', name: 'b'),
    const RetailerOffer(id: 'c', name: 'c', price: 2),
  ];
  check(
    sortOffers(offers, false).map((o) => o.id).join() == 'cab',
    'ascending price with unknown last',
  );
  check(
    sortOffers(offers, true).map((o) => o.id).join() == 'acb',
    'descending price with unknown last',
  );
  final invalid = before.toJson()..['weeks'] = 5;
  try {
    SavedShoppingList.fromJson(invalid);
    throw StateError('Invalid shopping range accepted');
  } on FormatException {
    print('PASS invalid shopping range rejected');
  }
  final prepared = SavedShoppingList(
    start: DateTime(2026),
    weeks: 1,
    sourceRevision: 0,
    rows: [
      const ShoppingRow(
        key: 'a',
        name: 'chicken',
        unit: 'lb',
        quantity: 2,
        preparation: 'bone-in',
      ),
    ],
  );
  check(
    shoppingText(prepared).contains('bone-in') &&
        shoppingCsv(prepared).contains('bone-in'),
    'exports preserve preparation',
  );
}
