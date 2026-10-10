import 'dart:convert';
import 'models.dart';
import 'recipe_guide_data.dart';

enum RecipeCollection {
  all('All ideas'),
  vegan('Vegan'),
  vegetarian('Vegetarian'),
  mealPrep('Meal prep');

  final String label;
  const RecipeCollection(this.label);
}

Map<String, Object>? recipeGuide(Recipe recipe) {
  final guide = recipeGuideData[recipe.id];
  if (guide == null ||
      recipe.incomplete ||
      recipe.sourceUrl != guide['source'] ||
      recipe.title != guide['title'] ||
      recipe.instructions != guide['instructions'])
    return null;
  return jsonEncode(recipe.ingredients.map((i) => i.toJson()).toList()) ==
          guide['ingredientRecord']
      ? guide
      : null;
}

bool inCollection(Recipe recipe, RecipeCollection collection) {
  if (collection == RecipeCollection.all) return true;
  final guide = recipeGuide(recipe);
  if (guide == null) return false;
  return switch (collection) {
    RecipeCollection.all => true,
    RecipeCollection.vegan => guide['vegan'] == true,
    RecipeCollection.vegetarian => guide['vegetarian'] == true,
    RecipeCollection.mealPrep => (guide['mealPrep'] as String).isNotEmpty,
  };
}

List<String> recipeRegions(Iterable<Recipe> recipes) =>
    recipes
        .map((r) => r.region.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

List<Recipe> discoverRecipes(
  Iterable<Recipe> recipes, {
  String query = '',
  String region = '',
  String category = 'all',
  RecipeCollection collection = RecipeCollection.all,
  bool favoritesOnly = false,
  Set<String> favorites = const {},
}) {
  final terms = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);
  return recipes.where((r) {
      final text = [
        r.title,
        r.region,
        r.category,
        ...r.ingredients.map((i) => i.name),
      ].join(' ').toLowerCase();
      return terms.every(text.contains) &&
          (region.isEmpty || r.region.trim() == region) &&
          (category == 'all' || r.category == category) &&
          (!favoritesOnly || favorites.contains(r.id)) &&
          inCollection(r, collection);
    }).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
}
