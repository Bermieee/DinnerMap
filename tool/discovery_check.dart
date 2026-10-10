import 'dart:convert';
import 'dart:io';
import '../lib/features/planner/models.dart';
import '../lib/features/planner/recipe_discovery.dart';
import 'export_starter_recipes.dart' show loadRecipes;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
  print('PASS $message');
}

void main() {
  final recipes = loadRecipes(
    jsonDecode(File('assets/recipes.json').readAsStringSync()) as List,
  );
  check(
    discoverRecipes(
      recipes,
      query: '  jApAnEsE   pork ',
    ).any((r) => r.id == 'dm-01'),
    'search combines region and ingredient terms',
  );
  check(
    discoverRecipes(
      recipes,
      region: 'German',
    ).every((r) => r.region == 'German'),
    'region excludes other cuisines',
  );
  final vegan = discoverRecipes(recipes, collection: RecipeCollection.vegan);
  check(
    vegan.map((r) => r.id).toSet().containsAll({
          'vegan-01',
          'vegan-02',
          'vegan-03',
        }) &&
        vegan.length == 3,
    'three source-checked vegan meals available',
  );
  check(
    discoverRecipes(
          recipes,
          collection: RecipeCollection.vegan,
          region: 'Indian',
        ).single.id ==
        'vegan-02',
    'diet and region combine',
  );
  check(
    !vegan.any((r) => r.id == 'fr-02'),
    'egg fried rice is not labeled vegan',
  );
  check(
    discoverRecipes(
      recipes,
      collection: RecipeCollection.vegetarian,
    ).any((r) => r.id == 'fr-02'),
    'vegetarian ideas include egg fried rice',
  );
  check(
    discoverRecipes(
      recipes,
      collection: RecipeCollection.mealPrep,
    ).any((r) => r.id == 'vegan-01'),
    'meal prep includes vegan batch dinners',
  );
  final changed = Recipe.fromJson({
    ...vegan.first.toJson(),
    'ingredients': [
      ...vegan.first.ingredients.map((i) => i.toJson()),
      const Ingredient(name: 'chicken').toJson(),
    ],
  });
  check(
    !inCollection(changed, RecipeCollection.vegan),
    'edited meat ingredient removes vegan label',
  );
  final editedNotes = Recipe.fromJson({
    ...vegan.first.toJson(),
    'instructions': 'Add chicken before serving',
  });
  check(
    !inCollection(editedNotes, RecipeCollection.vegan),
    'unreviewed directions remove dietary labels',
  );
  check(
    discoverRecipes(recipes, query: 'nonexistent-dinner-xyz').isEmpty,
    'no-match query stays empty',
  );
  check(
    discoverRecipes(
          recipes,
          favoritesOnly: true,
          favorites: {'vegan-02'},
        ).single.id ==
        'vegan-02',
    'favorites remain composable',
  );
}
