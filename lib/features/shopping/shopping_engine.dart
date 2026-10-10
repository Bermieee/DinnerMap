import '../planner/models.dart';

class Measure {
  final double? quantity;
  final String unit;
  const Measure(this.quantity, this.unit);
}

Measure parseMeasure(String raw) {
  var s = raw.trim().toLowerCase();
  const fractions = {
    '½': '1/2',
    '⅓': '1/3',
    '⅔': '2/3',
    '¼': '1/4',
    '¾': '3/4',
    '⅛': '1/8',
    '⅜': '3/8',
    '⅝': '5/8',
    '⅞': '7/8',
  };
  for (final e in fractions.entries) {
    s = s.replaceAll(e.key, ' ${e.value}');
  }
  final m = RegExp(
    r'^\s*((?:\d+(?:\.\d+)?\s+)?\d+/\d+|\d+(?:\.\d+)?)\s*([a-z ]*)$',
  ).firstMatch(s);
  if (m == null) return const Measure(null, 'text');
  double q = 0;
  for (final part in m[1]!.trim().split(RegExp(r'\s+'))) {
    if (part.contains('/')) {
      final p = part.split('/');
      final denominator = double.parse(p[1]);
      if (denominator == 0) return const Measure(null, 'text');
      q += double.parse(p[0]) / denominator;
    } else {
      q += double.parse(part);
    }
  }
  const aliases = {
    '': 'count',
    'pound': 'lb',
    'pounds': 'lb',
    'lbs': 'lb',
    'ounce': 'oz',
    'ounces': 'oz',
    'grams': 'g',
    'gram': 'g',
    'kilograms': 'kg',
    'cups': 'cup',
    'tablespoons': 'tbsp',
    'tablespoon': 'tbsp',
    'tbs': 'tbsp',
    'teaspoons': 'tsp',
    'teaspoon': 'tsp',
    'large': 'large',
    'medium': 'medium',
    'small': 'small',
    'cloves': 'clove',
    'cans': 'can',
    'pieces': 'count',
  };
  final u = m[2]!.trim();
  return Measure(q, aliases[u] ?? u);
}

const massFactors = {
  'g': 1.0,
  'kg': 1000.0,
  'oz': 28.349523125,
  'lb': 453.59237,
};
const volumeFactors = {
  'ml': 1.0,
  'l': 1000.0,
  'cup': 236.5882365,
  'tbsp': 14.78676478125,
  'tsp': 4.92892159375,
  'fl oz': 29.5735295625,
};
String family(String unit) => massFactors.containsKey(unit)
    ? 'mass'
    : volumeFactors.containsKey(unit)
    ? 'volume'
    : unit;
double factor(String unit) => massFactors[unit] ?? volumeFactors[unit] ?? 1;
String ingredientIdentity(Ingredient i) =>
    '${i.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}|${i.preparation.trim().toLowerCase()}';

class ShoppingRow {
  final String key, name, unit, preparation;
  final double? quantity;
  final List<String> sourceText;
  const ShoppingRow({
    required this.key,
    required this.name,
    required this.unit,
    required this.quantity,
    this.preparation = '',
    this.sourceText = const [],
  });
  double amountIn(String target) {
    if (quantity == null || family(target) != family(unit))
      throw ArgumentError('Incompatible conversion');
    return quantity! * factor(unit) / factor(target);
  }

  double? estimatedOz(double perPiece) =>
      quantity != null &&
          ['count', 'large', 'medium', 'small'].contains(unit) &&
          perPiece.isFinite &&
          perPiece > 0
      ? quantity! * perPiece
      : null;
  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'unit': unit,
    'quantity': quantity,
    'preparation': preparation,
    'sourceText': sourceText,
  };
  factory ShoppingRow.fromJson(Map<String, dynamic> j) => ShoppingRow(
    key: j['key'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String,
    quantity: (j['quantity'] as num?)?.toDouble(),
    preparation: j['preparation'] as String? ?? '',
    sourceText: List<String>.from(j['sourceText'] as List? ?? []),
  );
}

class ShoppingResult {
  final List<ShoppingRow> rows;
  final List<String> warnings;
  const ShoppingResult(this.rows, this.warnings);
}

class ShoppingEngine {
  static ShoppingResult generate({
    required List<PlanEntry> entries,
    required Map<String, Recipe> recipes,
    required DateTime start,
    required int weeks,
  }) {
    if (weeks < 1 || weeks > 4) throw ArgumentError('Choose 1–4 weeks');
    final first = dateOnly(start);
    final end = DateTime(first.year, first.month, first.day + weeks * 7);
    final totals = <String, ShoppingRow>{};
    final warnings = <String>{};
    for (final e in entries) {
      if (e.date.isBefore(first) ||
          !e.date.isBefore(end) ||
          e.kind != EntryKind.recipe)
        continue;
      final r = recipes[e.recipeId];
      if (r == null) {
        warnings.add('Missing recipe for ${dateKey(e.date)}');
        continue;
      }
      final known = r.baseServings != null && r.baseServings! > 0;
      final scale = known ? e.targetServings / r.baseServings! : 1.0;
      if (!known)
        warnings.add(
          '${r.title}: serving count unknown; original recipe amounts used.',
        );
      if (r.incomplete)
        warnings.add('${r.title}: source ingredient list is incomplete.');
      if (r.ingredients.isEmpty)
        warnings.add('${r.title}: no ingredient quantities available.');
      for (final i in r.ingredients) {
        final numeric =
            i.quantity != null && i.quantity!.isFinite && i.quantity! > 0;
        final unit = numeric
            ? (family(i.unit) == 'mass'
                  ? 'g'
                  : family(i.unit) == 'volume'
                  ? 'ml'
                  : i.unit)
            : 'text';
        final key =
            '${ingredientIdentity(i)}|${family(i.unit)}${numeric ? '' : '|${i.originalText}'}';
        final old = totals[key];
        if (!numeric)
          warnings.add('${i.name}: review quantity “${i.originalText}”.');
        totals[key] = ShoppingRow(
          key: key,
          name: i.name,
          unit: unit,
          quantity: numeric
              ? (old?.quantity ?? 0) + i.quantity! * scale * factor(i.unit)
              : null,
          preparation: i.preparation,
          sourceText: [
            ...?old?.sourceText,
            if (i.originalText.isNotEmpty) i.originalText,
          ],
        );
      }
    }
    final rows = totals.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ShoppingResult(rows, warnings.toList());
  }
}

int packagesRequired(double requiredAmount, double packageAmount) {
  if (!requiredAmount.isFinite ||
      !packageAmount.isFinite ||
      requiredAmount < 0 ||
      packageAmount <= 0)
    throw ArgumentError(
      'Amounts must be finite; package size must be positive',
    );
  return (requiredAmount / packageAmount).ceil();
}
