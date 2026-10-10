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
  };
  if (forms.any((w) => found.contains(w) && !wanted.contains(w))) return false;
  return true;
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
