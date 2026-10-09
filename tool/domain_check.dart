import '../lib/features/planner/models.dart';
import '../lib/features/shopping/shopping_engine.dart';

void main() {
  void check(bool value, String name) {
    if (!value) throw StateError(name);
    print('PASS $name');
  }

  final r = Recipe(
    id: 'a',
    title: 'Dinner',
    ingredients: [const Ingredient(name: 'salt', originalText: 'to taste')],
  );
  check(
    Recipe.fromJson(r.toJson()).baseServings == null,
    'unknown servings round trip',
  );
  check(
    PlanEntry.fromJson(
          PlanEntry(
            id: 'a',
            date: DateTime(2027, 1, 1),
            kind: EntryKind.takeout,
          ).toJson(),
        ).date ==
        DateTime(2027, 1, 1),
    'date round trip',
  );
  check(parseMeasure('1 ½ pounds').quantity == 1.5, 'mixed fraction');
  check(parseMeasure('2 (9-inch)').quantity == null, 'uncertain measure');
  final result = ShoppingEngine.generate(
    entries: [
      PlanEntry(id: 'a', date: DateTime(2026, 12, 20), recipeId: 'r'),
      PlanEntry(id: 'b', date: DateTime(2027, 1, 9), recipeId: 'r'),
      PlanEntry(id: 'c', date: DateTime(2027, 1, 10), recipeId: 'r'),
    ],
    recipes: {
      'r': const Recipe(
        id: 'r',
        title: 'Dinner',
        baseServings: 4,
        ingredients: [
          Ingredient(name: 'beef', quantity: 1, unit: 'lb'),
          Ingredient(name: 'beef', quantity: 8, unit: 'oz'),
        ],
      ),
    },
    start: DateTime(2026, 12, 20),
    weeks: 3,
  );
  check(
    (result.rows.single.amountIn('oz') - 48).abs() < 0.001,
    'date range and compatible mass',
  );
  check(packagesRequired(5.1, 2.5) == 3, 'package rounding');
  check(
    parseBaseServings('Serves 2–3') == null,
    'serving ranges remain unconfirmed',
  );
  check(
    parseBaseServings('Serves 4; makes 28–30') == 4,
    'explicit serving count accepted',
  );
}
