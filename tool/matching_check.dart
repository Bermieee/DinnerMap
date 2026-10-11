import '../lib/features/shopping/automatic_pricing.dart';
import '../lib/features/shopping/consumer_amounts.dart';
import '../lib/features/planner/models.dart';
import '../lib/features/shopping/product_search.dart';
import '../lib/features/shopping/shopping_pricing.dart';
import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/region/region_models.dart';

Future<void> main() async {
  final matches = <String, String>{
    'boneless chicken breasts':
        'Kroger® Boneless Skinless Chicken Breast Chunks with Rib Meat',
    'barbecue sauce': 'Kroger® Original Classic BBQ Sauce',
    'black pepper': 'McCormick Pure Ground Black Pepper',
    'all-purpose flour': 'King Arthur All Purpose Unbleached Flour',
    'jalapeño peppers': 'Kroger Jalapeno Peppers',
    'bay leaves': 'Kroger Bay Leaves',
    'scallions': 'Kroger Green Onions',
    'plain breadcrumbs': 'Kroger Plain Bread Crumbs',
    'chilli powder': 'Kroger Chili Powder',
    'fresh parsley': 'Kroger Parsley',
    'cumin': 'McCormick Ground Cumin',
    'ground cumin': 'Kroger Cumin',
    'egg': 'Kroger Large Brown Cage Free Eggs',
    'onion': 'Kroger Yellow Onions',
    'potatoes': 'Kroger Russet Potatoes',
    'tomatoes': 'Kroger Roma Tomatoes',
  };
  for (final entry in matches.entries) {
    if (!suitableProduct(entry.key, entry.value)) {
      throw StateError('Rejected ${entry.key}: ${entry.value}');
    }
  }
  for (final pair in <List<String>>[
    ['fresh parsley', 'Kroger Dried Parsley'],
    ['ginger', 'McCormick Ground Ginger'],
    ['black pepper', 'Kroger Whole Black Peppercorns'],
    ['all-purpose flour', 'Kroger Almond Flour'],
    ['potato', 'Kroger Sweet Potatoes'],
    ['red onion', 'Kroger Yellow Onions'],
    ['tomato', 'Kroger Cherry Tomatoes'],
    ['milk', 'Kroger Chocolate Milk'],
  ]) {
    if (suitableProduct(pair[0], pair[1]))
      throw StateError('Wrong form accepted: $pair');
  }
  for (final name in [
    'garlic for gravy',
    'soy sauce for dipping',
    'barbecue sauce for marinade',
  ]) {
    if (productSearchTerm(name).contains(' for '))
      throw StateError('Cooking use left in search: $name');
  }
  const row = ShoppingRow(
    key: 'p',
    name: 'black pepper',
    quantity: 0.25,
    unit: 'tsp',
  );
  const offer = ProductOffer(
    'p',
    'McCormick Ground Black Pepper',
    price: 3,
    amount: 3,
    unit: 'oz',
    storeId: 's',
    soldBy: 'UNIT',
  );
  if (suggestPackages(row, offer) != 1)
    throw StateError('Pepper spoon to retail weight');
  if (automaticReviewReason(row, [], 's') !=
      'Kroger returned no products. Try a broader search.')
    throw StateError('Empty search reason');
  if (!automaticReviewReason(row, [offer], 'other').contains('selected store'))
    throw StateError('Store mismatch reason');
  const sauce = ShoppingRow(
    key: 'sauce',
    name: 'barbecue sauce',
    quantity: 1,
    unit: 'cup',
  );
  const bottle = ProductOffer(
    'b',
    'Kroger BBQ Sauce',
    price: 2,
    amount: 18,
    unit: 'oz',
    storeId: 's',
    soldBy: 'UNIT',
  );
  if (suggestPackages(sauce, bottle) != 1)
    throw StateError('Sauce cup to bottle weight');
  const choice = ShoppingRow(
    key: 'choice',
    name: 'apple or Asian pear',
    quantity: 1,
    unit: 'count',
  );
  const mixed = ProductOffer(
    'mix',
    'Apple Asian Pear',
    price: 2,
    amount: 2,
    unit: 'count',
    storeId: 's',
    soldBy: 'UNIT',
  );
  if (bestDeal(choice, [mixed], 's') != null)
    throw StateError('Recipe alternatives must be chosen');
  if (canonicalRecipeUnit(parseMeasure('1 tsp optional').unit) != 'tsp')
    throw StateError('Optional spice unit');
  const oil = ShoppingRow(
    key: 'oil',
    name: 'vegetable oil',
    quantity: 1,
    unit: 'qt',
  );
  const jug = ProductOffer(
    'oil',
    'Kroger Vegetable Oil',
    price: 5,
    amount: 32,
    unit: 'fl oz',
    storeId: 's',
    soldBy: 'UNIT',
  );
  if (suggestPackages(oil, jug) != 1) throw StateError('Quart to fluid ounce');
  const legacy = ShoppingRow(
    key: 'legacy',
    name: 'black pepper',
    quantity: 0.25,
    unit: 'tsp optional',
  );
  if (suggestPackages(legacy, offer) != 1)
    throw StateError('Saved optional unit remains usable');
  const optional = Ingredient(
    name: 'five-spice powder',
    quantity: 0.25,
    unit: 'tsp optional',
    originalText: '¼ tsp optional',
  );
  if (!recipeIngredientAmount(optional).contains('optional'))
    throw StateError('Optional cooking label lost');
  var attempts = 0;
  final recovered = await searchWithTransientRetry(
    () async {
      if (++attempts == 1)
        throw StateError('Kroger is temporarily unavailable.');
      return [offer];
    },
    isCurrent: () => true,
    retryDelay: Duration.zero,
  );
  if (attempts != 2 || bestDeal(row, recovered, 's')?.packages != 1)
    throw StateError('Transient search did not recover');
  attempts = 0;
  try {
    await searchWithTransientRetry(
      () async {
        attempts++;
        throw StateError('Kroger request limit reached. Try again shortly.');
      },
      isCurrent: () => true,
      retryDelay: Duration.zero,
    );
    throw StateError('Quota should fail');
  } on StateError {
    if (attempts != 1) throw StateError('Quota was retried');
  }
  print('PASS catalog matching regressions');
}
