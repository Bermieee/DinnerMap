import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';

void main() {
  ShoppingResult generate(
    List<Ingredient> ingredients, {
    int? servings = 4,
    int target = 4,
  }) => ShoppingEngine.generate(
    entries: [
      PlanEntry(
        id: 'a',
        date: DateTime(2026, 12, 20),
        recipeId: 'r',
        targetServings: target,
      ),
    ],
    recipes: {
      'r': Recipe(
        id: 'r',
        title: 'Dinner',
        baseServings: servings,
        ingredients: ingredients,
      ),
    },
    start: DateTime(2026, 12, 20),
    weeks: 3,
  );
  test('compatible mass totals convert to ounces', () {
    final r = generate([
      Ingredient(name: 'beef', quantity: 1, unit: 'lb'),
      Ingredient(name: 'beef', quantity: 8, unit: 'oz'),
    ]);
    expect(r.rows.length, 1);
    expect(r.rows.first.amountIn('oz'), closeTo(24, 0.001));
  });
  test('preparation and unit families stay separate', () {
    final r = generate([
      Ingredient(
        name: 'chicken',
        quantity: 1,
        unit: 'lb',
        preparation: 'bone-in',
      ),
      Ingredient(
        name: 'chicken',
        quantity: 1,
        unit: 'lb',
        preparation: 'boneless',
      ),
      Ingredient(name: 'flour', quantity: 1, unit: 'cup'),
      Ingredient(name: 'flour', quantity: 1, unit: 'g'),
    ]);
    expect(r.rows.length, 4);
  });
  test('unknown servings preserve original amounts and warn', () {
    final r = generate(
      [Ingredient(name: 'beef', quantity: 1, unit: 'lb')],
      servings: null,
      target: 8,
    );
    expect(r.rows.first.amountIn('lb'), closeTo(1, 0.001));
    expect(r.warnings, isNotEmpty);
  });
  test('known servings scale quantities', () {
    final r = generate([
      Ingredient(name: 'beef', quantity: 1, unit: 'lb'),
    ], target: 8);
    expect(r.rows.first.amountIn('lb'), closeTo(2, 0.001));
  });
  test('range includes year boundary but excludes end date and takeout', () {
    final entries = [
      for (final d in [
        DateTime(2026, 12, 20),
        DateTime(2027, 1, 9),
        DateTime(2027, 1, 10),
      ])
        PlanEntry(id: d.toString(), date: d, recipeId: 'r'),
      PlanEntry(
        id: 'out',
        date: DateTime(2026, 12, 21),
        kind: EntryKind.takeout,
      ),
      PlanEntry(
        id: 'left',
        date: DateTime(2026, 12, 22),
        recipeId: 'r',
        kind: EntryKind.leftovers,
      ),
    ];
    final r = ShoppingEngine.generate(
      entries: entries,
      recipes: {
        'r': Recipe(
          id: 'r',
          title: 'Dinner',
          baseServings: 4,
          ingredients: [Ingredient(name: 'egg', quantity: 1, unit: 'count')],
        ),
      },
      start: DateTime(2026, 12, 20),
      weeks: 3,
    );
    expect(r.rows.single.quantity, 2);
  });
  test('missing recipe warns', () {
    final r = ShoppingEngine.generate(
      entries: [
        PlanEntry(id: 'a', date: DateTime(2026, 1, 1), recipeId: 'missing'),
      ],
      recipes: {},
      start: DateTime(2026, 1, 1),
      weeks: 1,
    );
    expect(r.warnings, isNotEmpty);
  });
  test('package rounding validates sizes', () {
    expect(packagesRequired(5, 2.5), 2);
    expect(packagesRequired(5.1, 2.5), 3);
    expect(() => packagesRequired(5, 0), throwsArgumentError);
  });
  test('fraction parser retains uncertain package measures', () {
    expect(parseMeasure('1 ½ pounds').quantity, 1.5);
    expect(parseMeasure('⅓ cup').quantity, closeTo(1 / 3, 0.0001));
    expect(parseMeasure('2 (9-inch)').quantity, isNull);
    expect(parseMeasure('to taste').quantity, isNull);
  });
  test('counts retain original quantity when estimating weights', () {
    final r = generate([
      Ingredient(name: 'chicken thighs', quantity: 18, unit: 'count'),
    ]);
    expect(r.rows.single.quantity, 18);
    expect(r.rows.single.estimatedOz(6), 108);
  });
  test('invalid week selection rejected', () {
    expect(
      () => ShoppingEngine.generate(
        entries: [],
        recipes: {},
        start: DateTime(2026),
        weeks: 5,
      ),
      throwsArgumentError,
    );
  });
}
