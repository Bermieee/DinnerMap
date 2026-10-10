import '../planner/models.dart';
import 'shopping_engine.dart';

// Display only. Stored amounts retain full precision for package calculations.
String friendlyNumber(double value) {
  final fractions = <double, String>{
    0: '',
    1 / 8: '1/8',
    1 / 4: '1/4',
    1 / 3: '1/3',
    3 / 8: '3/8',
    1 / 2: '1/2',
    5 / 8: '5/8',
    2 / 3: '2/3',
    3 / 4: '3/4',
    7 / 8: '7/8',
    1: '',
  };
  final whole = value.floor(), remainder = value - value.floor();
  for (final entry in fractions.entries) {
    if ((remainder - entry.key).abs() < 0.0001) {
      final integer = whole + (entry.key == 1 ? 1 : 0);
      return entry.value.isEmpty
          ? '$integer'
          : integer == 0
          ? entry.value
          : '$integer ${entry.value}';
    }
  }
  final result = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return result == '0' && value > 0 ? '<0.01' : result;
}

String readableAmount(double quantity, String unit, {String massUnit = 'lb'}) {
  if (family(unit) == 'volume') {
    final ml = quantity * factor(unit);
    final cup = ml / factor('cup');
    // Keep familiar exact cup fractions; use spoons for smaller quantities.
    if (cup >= 0.25 &&
        (cup >= 1 ||
            [
              0.25,
              1 / 3,
              0.5,
              2 / 3,
              0.75,
            ].any((n) => (cup - n).abs() < 0.0001))) {
      return '${friendlyNumber(cup)} ${cup > 1.0001 ? 'cups' : 'cup'}';
    }
    final tbsp = ml / factor('tbsp');
    if (tbsp >= 1) return '${friendlyNumber(tbsp)} tbsp';
    return '${friendlyNumber(ml / factor('tsp'))} tsp';
  }
  if (family(unit) == 'mass') {
    final amount = quantity * factor(unit) / factor(massUnit);
    if (massUnit == 'lb' && amount < 1)
      return '${friendlyNumber(amount * 16)} oz';
    return '${friendlyNumber(amount)} $massUnit';
  }
  return '${friendlyNumber(quantity)}${unit == 'count' ? ' pieces' : ' $unit'}';
}

String recipeIngredientAmount(Ingredient ingredient) {
  final q = ingredient.quantity;
  if (q == null || !q.isFinite || q <= 0)
    return ingredient.originalText.isEmpty
        ? 'Review amount'
        : ingredient.originalText;
  if (family(ingredient.unit) == 'mass')
    return '${friendlyNumber(q)} ${ingredient.unit}';
  return readableAmount(q, ingredient.unit);
}

// Estimated purchase conversion only, not a replacement for recipe measurements.
// King Arthur Baking ingredient weight chart, checked 2026-10-10:
// https://www.kingarthurbaking.com/learn/ingredient-weight-chart
// Exact names avoid assuming cooked rice, flour blends, or prepared foods match.
double? gramsPerCup(String name, {String preparation = ''}) {
  if (preparation.trim().isNotEmpty) return null;
  final normalized = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return switch (normalized) {
    'flour' ||
    'all-purpose flour' ||
    'all purpose flour' ||
    'plain flour' ||
    'bread flour' => 120,
    'sugar' || 'white sugar' || 'granulated sugar' => 198,
    'cornstarch' || 'corn starch' => 112,
    'butter' || 'salted butter' || 'unsalted butter' => 226,
    'dry long-grain rice' || 'uncooked long-grain rice' => 198,
    'olive oil' => 200,
    'vegetable oil' => 198,
    'heavy cream' => 227,
    _ => null,
  };
}

double? estimatedPurchaseGrams(ShoppingRow row) {
  if (row.quantity == null || family(row.unit) != 'volume') return null;
  final density = gramsPerCup(row.name, preparation: row.preparation);
  return density == null ? null : row.amountIn('cup') * density;
}

String purchaseHint(ShoppingRow row, {String massUnit = 'lb'}) {
  final q = row.quantity;
  if (q == null) return 'Review amount before buying';
  if (['count', 'large', 'medium', 'small'].contains(row.unit))
    return 'Buy ${q.ceil()} ${row.name}';
  if (row.unit == 'can')
    return 'Buy ${q.ceil()} can${q.ceil() == 1 ? '' : 's'}; check can size';
  final grams = estimatedPurchaseGrams(row);
  if (grams != null)
    return 'Buy enough for about ${readableAmount(grams, 'g', massUnit: massUnit)}; choose a package';
  if (family(row.unit) == 'mass') {
    final target = massUnit == 'lb' && row.amountIn('lb') < 1 ? 'oz' : massUnit;
    final roundedUp = (row.amountIn(target) * 100).ceil() / 100;
    return 'Buy at least ${readableAmount(roundedUp, target, massUnit: target)}';
  }
  return 'Choose a package to calculate how many to buy';
}
