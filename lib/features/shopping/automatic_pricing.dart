import '../region/region_models.dart';
import 'shopping_engine.dart';
import 'shopping_pricing.dart';
import 'product_search.dart';

Set<String> _words(String text) => RegExp(r'[a-z0-9]+')
    .allMatches(text.toLowerCase())
    .map((m) {
      final word = m.group(0)!;
      return word.length > 3 && word.endsWith('s')
          ? word.substring(0, word.length - 1)
          : word;
    })
    .where((w) => !{'and', 'or', 'the'}.contains(w))
    .toSet();

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
  if (forms.any((w) => found.contains(w) && !wanted.contains(w))) return false;
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
