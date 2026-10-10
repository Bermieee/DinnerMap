import '../../data/planner_repository.dart';
import '../shopping/shopping_engine.dart';
import 'models.dart';

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

PlannerSnapshot addDiscoveryStarters(
  PlannerSnapshot saved,
  List<Recipe> bundled,
) {
  const additions = {'vegan-01', 'vegan-02', 'vegan-03'};
  // Preserve deliberately empty or entirely custom libraries.
  if (!bundled.any(
    (r) => !additions.contains(r.id) && saved.recipes.containsKey(r.id),
  ))
    return saved;
  final missing = bundled
      .where(
        (r) => additions.contains(r.id) && !saved.recipes.containsKey(r.id),
      )
      .toList();
  if (missing.isEmpty) return saved;
  return saved.copyWith(
    recipes: {...saved.recipes, for (final r in missing) r.id: r},
    revision: saved.revision + 1,
  );
}
