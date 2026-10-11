import 'dart:convert';
import 'dart:io';
import '../lib/features/shopping/product_search.dart';
import '../lib/features/planner/starter_recipes.dart';
import '../lib/features/planner/recipe_discovery.dart';
import '../lib/features/planner/recipe_guide_data.dart';
import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/shopping/consumer_amounts.dart';
import '../lib/features/shopping/automatic_pricing.dart';

// A complete static audit of bundled recipe lines, not a live Kroger inventory
// test. Every line gets a search and a calculation limitation, if applicable.
void main(List<String> args) {
  final recipes =
      jsonDecode(File('assets/recipes.json').readAsStringSync()) as List;
  final loaded = loadRecipes(recipes);
  for (final recipe in loaded.where((r) => recipeGuideData.containsKey(r.id))) {
    if (recipeGuide(recipe) == null)
      throw StateError('Curated guide invalidated: ${recipe.id}');
  }
  final lines = <List<String>>[];
  final categories = <String, int>{};
  final names = <String>{};
  for (final recipe in recipes) {
    for (final ingredient in recipe['ingredients'] as List) {
      final name = ingredient['name'] as String;
      final measure = ingredient['measure'] as String;
      names.add(name);
      final parsed = parseMeasure(measure);
      final row = ShoppingRow(
        key: name,
        name: name,
        quantity: parsed.quantity,
        unit: parsed.unit,
      );
      final search = productSearchTerm(name);
      if (search.isEmpty) throw StateError('Empty search for $name');
      final preflight = automaticPreflightReason(row);
      final String status;
      if (preflight != null) {
        status = preflight;
      } else if (family(row.unit) == 'mass') {
        status = 'Can compare with fixed weight packages; live offer required.';
      } else if (family(row.unit) == 'volume') {
        status = estimatedPurchaseGrams(row) != null
            ? 'Can compare with fixed volume or estimated weight packages; live offer required.'
            : 'Can compare with fixed volume packages; weight packages need a conversion or manual count.';
      } else if ([
        'count',
        'large',
        'medium',
        'small',
      ].contains(family(row.unit))) {
        status =
            'Can compare with counted packages; weight packages need a per-piece estimate.';
      } else {
        status =
            'Recipe unit ${row.unit} needs a compatible package or manual count.';
      }
      if (!suitableProduct(search, search))
        throw StateError('Identity rejected: $name => $search');
      categories[status] = (categories[status] ?? 0) + 1;
      lines.add([
        recipe['id'] as String,
        recipe['name'] as String,
        name,
        measure,
        search,
        status,
      ]);
    }
  }
  final output = StringBuffer(
    'recipe_id,recipe,ingredient,measure,search,assessment\n',
  );
  for (final line in lines) {
    output.writeln(line.map((v) => '"${v.replaceAll('"', '""')}"').join(','));
  }
  final file = File('docs/ingredient-search-audit.csv');
  if (args.contains('--check')) {
    if (!file.existsSync() || file.readAsStringSync() != output.toString())
      throw StateError(
        'Catalog audit out of date. Run dart tool/catalog_audit.dart',
      );
  } else {
    file.writeAsStringSync(output.toString());
  }
  print(
    'PASS audited ${recipes.length} recipes, ${names.length} distinct names, ${lines.length} ingredient lines',
  );
  for (final entry in categories.entries) {
    print('${entry.value}: ${entry.key}');
  }
}
