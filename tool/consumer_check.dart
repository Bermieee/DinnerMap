import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/shopping/consumer_amounts.dart';
import '../lib/features/shopping/shopping_export.dart';
import '../lib/features/planner/models.dart';
import '../lib/features/shopping/shopping_models.dart';
import '../lib/features/shopping/shopping_pricing.dart';
import '../lib/features/region/region_models.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
  print('PASS $message');
}

void main() {
  const flour = ShoppingRow(
    key: 'flour',
    name: 'all-purpose flour',
    unit: 'ml',
    quantity: 78.8627455,
  );
  check(
    rowAmount(flour, 'lb') == '1/3 cup',
    'flour volume is a readable fraction rather than internal millilitres',
  );
  check(
    suggestPackages(
          flour,
          const ProductOffer(
            'bag',
            'All-purpose flour',
            price: 3,
            amount: 5,
            unit: 'lb',
            soldBy: 'UNIT',
            storeId: '123',
          ),
        ) ==
        1,
    'flour volume converts to a whole bag recommendation',
  );
  const unknown = ShoppingRow(
    key: 'mystery',
    name: 'mystery powder',
    unit: 'cup',
    quantity: 3,
  );
  check(
    suggestPackages(
          unknown,
          const ProductOffer(
            'bag',
            'Powder',
            amount: 1,
            unit: 'lb',
            soldBy: 'UNIT',
          ),
        ) ==
        null,
    'unknown ingredient density does not invent a package count',
  );
  check(
    readableAmount(2.5, 'tsp') == '2 1/2 tsp',
    'small recipe amounts use familiar spoon fractions',
  );
  check(
    recipeIngredientAmount(
          const Ingredient(name: 'flour', quantity: 120, unit: 'g'),
        ) ==
        '120 g',
    'recipe weight retains its original cooking unit',
  );
  check(
    recipeIngredientAmount(
          const Ingredient(name: 'salt', originalText: 'to taste'),
        ) ==
        'to taste',
    'unknown amounts preserve recipe instructions',
  );
  check(
    readableAmount(0.125, 'cup') == '2 tbsp',
    'small cup quantities convert to tablespoons',
  );
  check(
    purchaseHint(
          const ShoppingRow(
            key: 'onion',
            name: 'onion',
            unit: 'count',
            quantity: 1.5,
          ),
        ) ==
        'Buy 2 onion',
    'loose groceries round up to whole items',
  );
  check(
    gramsPerCup('cooked rice') == null &&
        gramsPerCup('almond flour') == null &&
        gramsPerCup('flour', preparation: 'packed') == null,
    'ingredient variants do not inherit unrelated density estimates',
  );
  final selected = PriceSelection(
    row: flour,
    offer: const ProductOffer(
      'bag',
      'All-purpose flour',
      size: '5 lb',
      amount: 5,
      unit: 'lb',
      price: 3,
      storeId: '123',
      soldBy: 'UNIT',
    ),
    packages: 1,
  );
  final list = SavedShoppingList(
    start: DateTime(2026, 10, 10),
    weeks: 1,
    sourceRevision: 1,
    rows: [flour],
  );
  check(
    shoppingText(
          list,
          selections: {'flour': selected},
        ).contains('Buy 1 × 5 lb') &&
        shoppingCsv(list, selections: {'flour': selected}).contains('1/3 cup'),
    'exports pair actual packages with readable recipe needs',
  );
  check(
    suggestPackages(
          const ShoppingRow(
            key: 'eggs',
            name: 'eggs',
            unit: 'large',
            quantity: 18,
          ),
          const ProductOffer(
            'carton',
            'Eggs',
            amount: 12,
            unit: 'count',
            soldBy: 'UNIT',
          ),
        ) ==
        2,
    'sized eggs map to counted cartons',
  );
  check(
    suggestPackages(
          const ShoppingRow(
            key: 'exact',
            name: 'oil',
            unit: 'ml',
            quantity: 473.17647300000006,
          ),
          const ProductOffer(
            'bottle',
            'Oil',
            amount: 16,
            unit: 'fl oz',
            soldBy: 'UNIT',
          ),
        ) ==
        1,
    'conversion noise does not add an unnecessary package',
  );
}
