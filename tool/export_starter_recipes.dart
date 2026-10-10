import 'dart:convert';
import 'dart:io';
import '../lib/features/planner/models.dart';
import '../lib/features/shopping/shopping_engine.dart';

List<Recipe> loadRecipes(List raw) {
  return raw.map((value) {
    final j = Map<String, dynamic>.from(value as Map);
    final yield = j['yieldNote'] as String? ?? '';
    final servings = parseBaseServings(yield);
    return Recipe(
      id: j['id'] as String,
      title: j['name'] as String,
      baseServings: servings,
      category: j['type'] as String? ?? 'quick',
      region: j['area'] as String? ?? '',
      sourceUrl: j['original'] as String? ?? '',
      incomplete: j['incomplete'] == true,
      instructions:
          'Open the source recipe for cooking directions. ${yield.isEmpty ? 'Original source quantities; confirm servings before scaling.' : yield}',
      ingredients: (j['ingredients'] as List).map((value) {
        final i = Map<String, dynamic>.from(value as Map);
        final measure = i['measure'] as String;
        final parsed = parseMeasure(measure);
        return Ingredient(
          name: i['name'] as String,
          quantity: parsed.quantity,
          unit: parsed.unit,
          originalText: measure,
        );
      }).toList(),
    );
  }).toList();
}

void main() {
  final raw =
      jsonDecode(File('assets/recipes.json').readAsStringSync()) as List;
  stdout.write(jsonEncode(loadRecipes(raw).map((r) => r.toJson()).toList()));
}
