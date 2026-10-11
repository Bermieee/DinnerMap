import '../region/region_models.dart';
import 'shopping_engine.dart';
import 'shopping_pricing.dart';
import 'product_search.dart';

// Normalize only known aliases/plurals. Removing every trailing "s" corrupts
// identity words such as boneless, skinless and purpose.
Set<String> _words(String text) {
  var normalized = text
      .toLowerCase()
      .replaceAll('jalapeño', 'jalapeno')
      .replaceAll(RegExp(r'\bbbq\b|\bbarbeque\b'), 'barbecue')
      .replaceAll(RegExp(r'\bbreadcrumbs?\b'), 'bread crumbs')
      .replaceAll(RegExp(r'\bscallions?\b'), 'green onions')
      .replaceAll(RegExp(r'\bchilli\b'), 'chili')
      .replaceAll(RegExp(r'\bfresh\b'), '')
      .replaceAllMapped(
        RegExp(r'\bground (cumin|black pepper|white pepper|cardamom|mace)\b'),
        (m) => m[1]!,
      );
  const plurals = {
    'breasts': 'breast',
    'thighs': 'thigh',
    'eggs': 'egg',
    'onions': 'onion',
    'peppers': 'pepper',
    'potatoes': 'potato',
    'tomatoes': 'tomato',
    'leaves': 'leaf',
    'berries': 'berry',
    'carrots': 'carrot',
    'mushrooms': 'mushroom',
    'cloves': 'clove',
    'beans': 'bean',
    'seeds': 'seed',
    'nuts': 'nut',
    'peas': 'pea',
    'pieces': 'piece',
    'crumbs': 'crumb',
    'tortillas': 'tortilla',
    'nuggets': 'nugget',
    'cookies': 'cookie',
    'crackers': 'cracker',
    'treats': 'treat',
    'sticks': 'stick',
    'pounds': 'pound',
    'ounces': 'ounce',
    'packs': 'pack',
    'bottles': 'bottle',
    'cans': 'can',
    'jars': 'jar',
  };
  return RegExp(r'[a-z0-9]+')
      .allMatches(normalized)
      .map((m) => plurals[m.group(0)!] ?? m.group(0)!)
      .where((w) => !{'and', 'or', 'the'}.contains(w))
      .toSet();
}

/// Conservative name matching. Suggestions always require user review.
/// Reject unfamiliar substitutions instead of filling the list with guesses.
bool suitableProduct(String ingredient, String product) {
  final wanted = _words(productSearchTerm(ingredient));
  final found = _words(product);
  if (wanted.isEmpty || !found.containsAll(wanted)) return false;
  const forms = {
    'broth',
    'soup',
    'sauce',
    'pizza',
    'nugget',
    'breaded',
    'cooked',
    'canned',
    'sausage',
    'patty',
    'chili',
    'seasoned',
    'marinated',
    'almond',
    'coconut',
    'soy',
    'oat',
    'powder',
    'concentrate',
    'peanut',
    'cashew',
    'hazelnut',
    'pistachio',
    'chocolate',
    'cookie',
    'cracker',
    'cereal',
    'snack',
    'popcorn',
    'tortilla',
    'cake',
    'muffin',
    'bread',
    'mix',
    'frosting',
    'brown',
    'powdered',
    'dog',
    'cat',
    'pet',
    'treat',
    'shampoo',
    'soap',
    'garlic',
    'pickled',
    'roasted',
    'smoked',
    'flavored',
    'seasoning',
  };
  if (forms.any(
    (w) =>
        found.contains(w) &&
        !wanted.contains(w) &&
        !(w == 'brown' && wanted.contains('egg')),
  ))
    return false;
  // Unknown food qualifiers are not evidence of an ingredient match. This
  // intentionally leaves unfamiliar brands/forms for manual product review.
  const neutral = {
    'kroger',
    'simple',
    'truth',
    'private',
    'selection',
    'organic',
    'natural',
    'fresh',
    'raw',
    'premium',
    'original',
    'pure',
    'brand',
    'farm',
    'mccormick',
    'oz',
    'ounce',
    'lb',
    'pound',
    'g',
    'kg',
    'ml',
    'l',
    'fl',
    'ct',
    'count',
    'pack',
    'package',
    'bag',
    'bottle',
    'carton',
    'can',
    'jar',
    'size',
  };
  const specific = {
    'onion': {'yellow', 'white', 'red', 'sweet'},
    'potato': {
      'russet',
      'yukon',
      'gold',
      'golden',
      'red',
      'white',
      'yellow',
      'baking',
    },
    'tomato': {'roma', 'plum', 'vine', 'ripe'},
    'parsley': {'flat', 'leaf', 'italian', 'curly'},
    'peanut': {'creamy', 'crunchy', 'smooth', 'skippy', 'jif'},
    'butter': {
      'salted',
      'unsalted',
      'sweet',
      'cream',
      'cultured',
      'stick',
      'land',
      'lake',
      'kerrygold',
      'irish',
      'challenge',
    },
    'chicken': {
      'boneless',
      'skinless',
      'breast',
      'thigh',
      'tenderloin',
      'whole',
      'frozen',
      'tyson',
      'perdue',
      'chunk',
      'chunks',
      'with',
      'rib',
      'meat',
      'uncooked',
      'fillet',
      'fillets',
      'portion',
      'portions',
      'sanderson',
      'farms',
      'heritage',
    },
    'milk': {
      'whole',
      'skim',
      'nonfat',
      'fat',
      'lowfat',
      'reduced',
      'percent',
      'homogenized',
      'pasteurized',
      'horizon',
      'fairlife',
    },
    'sugar': {'white', 'granulated', 'cane', 'refined', 'domino'},
    'cumin': {'ground', 'culinary'},
    'coriander': {'ground', 'culinary'},
    'ginger': {'culinary'},
    'cardamom': {'ground', 'culinary'},
    'mace': {'ground', 'culinary'},
    'paprika': {'culinary'},
    'pepper': {'ground', 'coarse', 'fine', 'mccormick', 'culinary'},
    'barbecue': {'sweet', 'baby', 'ray', 'rays', 's', 'classic'},
    'crumb': {'plain', 'dried', 'dry', 'progresso'},
    'flour': {
      'all',
      'purpose',
      'allpurpose',
      'unbleached',
      'bleached',
      'enriched',
      'wheat',
      'king',
      'arthur',
      'gold',
      'medal',
    },
    'rice': {'white', 'long', 'grain', 'jasmine', 'basmati', 'dry', 'uncooked'},
    'beef': {'ground', 'fresh', 'angus', 'chuck', 'round', 'sirloin', 'lean'},
    'egg': {
      'large',
      'medium',
      'small',
      'white',
      'brown',
      'grade',
      'a',
      'cage',
      'free',
      'range',
      'dozen',
    },
  };
  final allowed = {...wanted, ...neutral};
  for (final word in wanted) {
    allowed.addAll(specific[word] ?? const <String>{});
  }
  return found.every(
    (word) => allowed.contains(word) || RegExp(r'^\d+$').hasMatch(word),
  );
}

/// Lowest whole-package cost among returned, compatible fixed-unit offers.
/// Retailer identity remains in ProductOffer; other adapters can reuse this.
PriceSelection? bestDeal(
  ShoppingRow row,
  Iterable<ProductOffer> offers,
  String storeId, {
  double? pieceWeightOz,
}) {
  if (automaticPreflightReason(row) != null) return null;
  PriceSelection? best;
  for (final offer in offers) {
    if (offer.storeId != storeId ||
        !offer.knownPrice ||
        !suitableProduct(row.name, offer.name) ||
        RegExp(
          r'out.of.stock|unavailable',
          caseSensitive: false,
        ).hasMatch(offer.availability))
      continue;
    final count = suggestPackages(row, offer, pieceWeightOz: pieceWeightOz);
    if (count == null) continue;
    final selection = PriceSelection(row: row, offer: offer, packages: count);
    if (best == null ||
        selection.costCents < best.costCents ||
        (selection.costCents == best.costCents &&
            selection.offer.id.compareTo(best.offer.id) < 0))
      best = selection;
  }
  return best;
}

/// Explain the rejected offers without describing a calculation failure as
/// absence of an item. Manual review can still select a fixed package.
String automaticReviewReason(
  ShoppingRow row,
  Iterable<ProductOffer> offers,
  String storeId,
) {
  final preflight = automaticPreflightReason(row);
  if (preflight != null) return preflight;
  final all = offers.toList();
  if (all.isEmpty) return 'Kroger returned no products. Try a broader search.';
  final local = all.where((o) => o.storeId == storeId).toList();
  if (local.isEmpty) return 'No offers for the selected store. Search again.';
  final named = local.where((o) => suitableProduct(row.name, o.name)).toList();
  if (named.isEmpty) {
    return 'Products returned, but their names or food types need review. Choose a matching product.';
  }
  final stocked = named
      .where(
        (o) => !RegExp(
          r'out.of.stock|unavailable',
          caseSensitive: false,
        ).hasMatch(o.availability),
      )
      .toList();
  if (stocked.isEmpty)
    return 'Matching products are marked unavailable at this store.';
  final priced = stocked.where((o) => o.knownPrice).toList();
  if (priced.isEmpty) return 'Matching products have no price for this store.';
  final fixed = priced.where((o) => o.soldBy == 'UNIT').toList();
  if (fixed.isEmpty) {
    return priced.every((o) => o.soldBy == 'WEIGHT')
        ? 'Matching products are sold by weight. A fixed-package total is unavailable.'
        : 'Matching products need their package pricing basis confirmed.';
  }
  if (fixed.every((o) => o.normalizedAmount == null)) {
    return 'Matching products have an unknown package size. Review the package count.';
  }
  return 'Matching products found, but we cannot convert the recipe units to their package size. Review the package count.';
}

/// One paced retry for a transient service failure. Authentication, configuration,
/// request quotas and invalid searches require intervention, not more requests.
Future<List<ProductOffer>> searchWithTransientRetry(
  Future<List<ProductOffer>> Function() search, {
  required bool Function() isCurrent,
  Duration retryDelay = const Duration(milliseconds: 2200),
}) async {
  try {
    return await search();
  } on StateError catch (e) {
    final message = e.message.toString();
    const transient = {
      'Kroger is temporarily unavailable.',
      'Retailer service is unavailable. Try again.',
      'Store service is unavailable. Check connection and retry.',
    };
    if (!transient.contains(message) || !isCurrent()) rethrow;
    await Future<void>.delayed(retryDelay);
    if (!isCurrent()) rethrow;
    return search();
  }
}

String? automaticPreflightReason(ShoppingRow row) {
  if (row.quantity == null || !row.quantity!.isFinite || row.quantity! <= 0) {
    return 'Recipe amount needs review before package quantities can be calculated.';
  }
  final term = productSearchTerm(row.name).toLowerCase();
  if (RegExp(r'\bor\b').hasMatch(term)) {
    return 'Recipe lists alternatives. Choose the ingredient you want before pricing.';
  }
  if (RegExp(r'\band\b').hasMatch(term) &&
      term != 'half and half' &&
      !term.contains('peeled and deveined shrimp')) {
    return 'Recipe combines ingredients in one line. Split them before calculating packages.';
  }
  return null;
}
