import 'dart:convert';
import '../lib/features/planner/models.dart';
import '../lib/features/planner/recipe_discovery.dart';

// Public starter fixtures after a PostgreSQL JSON round trip.
const records =
    r'''[{"id":"fr-02","title":"Vegetable Fried Rice","region":"Chinese","category":"quick","sourceUrl":"https://www.budgetbytes.com/vegetable-fried-rice/","incomplete":false,"ingredients":[{"name":"garlic","unit":"clove","quantity":2,"preparation":"","originalText":"2 cloves"},{"name":"grated fresh ginger","unit":"tsp","quantity":1,"preparation":"","originalText":"1 tsp"},{"name":"carrot","unit":"count","quantity":1,"preparation":"","originalText":"1"},{"name":"red bell pepper","unit":"count","quantity":1,"preparation":"","originalText":"1"},{"name":"green onions","unit":"count","quantity":4,"preparation":"","originalText":"4"},{"name":"eggs","unit":"count","quantity":2,"preparation":"","originalText":"2"},{"name":"frozen peas","unit":"cup","quantity":1,"preparation":"","originalText":"1 cup"},{"name":"cooking oil","unit":"tbsp","quantity":3,"preparation":"","originalText":"3 Tbsp"},{"name":"cooked and cooled rice","unit":"cup","quantity":3,"preparation":"","originalText":"3 cups"},{"name":"soy sauce","unit":"tbsp","quantity":3,"preparation":"","originalText":"3 Tbsp"},{"name":"toasted sesame oil","unit":"tbsp","quantity":1,"preparation":"","originalText":"1 Tbsp"}],"baseServings":4,"instructions":"Open the source recipe for cooking directions. Serves 4"},{"id":"us-08","title":"Baked Macaroni and Cheese","region":"American","category":"favorite","sourceUrl":"https://www.allrecipes.com/recipe/14140/baked-macaroni-and-cheese/","incomplete":false,"ingredients":[{"name":"elbow macaroni","unit":"oz","quantity":12,"preparation":"","originalText":"12 ounces"},{"name":"whole milk","unit":"cup","quantity":2,"preparation":"","originalText":"2 cups"},{"name":"egg","unit":"large","quantity":1,"preparation":"","originalText":"1 large"},{"name":"shredded cheddar cheese","unit":"cup","quantity":2.5,"preparation":"","originalText":"2 ½ cups"},{"name":"butter, melted","unit":"tbsp","quantity":2,"preparation":"","originalText":"2 tablespoons"},{"name":"salt and pepper","unit":"text","quantity":null,"preparation":"","originalText":"to taste"}],"baseServings":null,"instructions":"Open the source recipe for cooking directions. Original source quantities; confirm servings before scaling."},{"id":"vegan-01","title":"Sweet Potato & Bean Chilli","region":"International","category":"favorite","sourceUrl":"https://www.bbcgoodfoodme.com/recipes/vegan-chilli/","incomplete":false,"ingredients":[{"name":"olive oil","unit":"tbsp","quantity":3,"preparation":"","originalText":"3 tbsp"},{"name":"sweet potatoes","unit":"count","quantity":2,"preparation":"","originalText":"2"},{"name":"smoked paprika","unit":"tsp","quantity":2,"preparation":"","originalText":"2 tsp"},{"name":"ground cumin","unit":"tsp","quantity":2,"preparation":"","originalText":"2 tsp"},{"name":"onion","unit":"count","quantity":1,"preparation":"","originalText":"1"},{"name":"carrots","unit":"count","quantity":2,"preparation":"","originalText":"2"},{"name":"celery stalks","unit":"count","quantity":2,"preparation":"","originalText":"2"},{"name":"garlic","unit":"clove","quantity":2,"preparation":"","originalText":"2 cloves"},{"name":"chilli powder","unit":"text","quantity":null,"preparation":"","originalText":"1–2 tsp"},{"name":"dried oregano","unit":"tsp","quantity":1,"preparation":"","originalText":"1 tsp"},{"name":"tomato puree","unit":"tbsp","quantity":1,"preparation":"","originalText":"1 tbsp"},{"name":"red bell pepper","unit":"count","quantity":1,"preparation":"","originalText":"1"},{"name":"chopped tomatoes","unit":"text","quantity":null,"preparation":"","originalText":"2 cans (400 g each)"},{"name":"black beans","unit":"text","quantity":null,"preparation":"","originalText":"1 can (400 g), drained"},{"name":"kidney beans","unit":"text","quantity":null,"preparation":"","originalText":"1 can (400 g), drained"},{"name":"water","unit":"ml","quantity":200,"preparation":"","originalText":"200 ml"},{"name":"lime, guacamole, coriander and rice","unit":"text","quantity":null,"preparation":"","originalText":"to serve"}],"baseServings":4,"instructions":"Open the source recipe for cooking directions. Serves 4; use the cooking source for directions. Choose vegan toppings."},{"id":"vegan-03","title":"Vegan Lentil & Kale Soup","region":"International","category":"favorite","sourceUrl":"https://www.loveandlemons.com/lentil-soup/","incomplete":false,"ingredients":[{"name":"olive oil","unit":"tbsp","quantity":2,"preparation":"","originalText":"2 tbsp"},{"name":"yellow onion","unit":"count","quantity":1,"preparation":"","originalText":"1"},{"name":"carrots","unit":"count","quantity":4,"preparation":"","originalText":"4"},{"name":"celery stalks","unit":"count","quantity":2,"preparation":"","originalText":"2"},{"name":"kale","unit":"text","quantity":null,"preparation":"","originalText":"6 small or 3 large leaves"},{"name":"ground cumin","unit":"text","quantity":null,"preparation":"","originalText":"heaping 1/2 tsp"},{"name":"sea salt","unit":"tsp","quantity":1.5,"preparation":"","originalText":"1.5 tsp"},{"name":"black pepper","unit":"text","quantity":null,"preparation":"","originalText":"to taste"},{"name":"garlic","unit":"clove","quantity":4,"preparation":"","originalText":"4 cloves"},{"name":"fire-roasted diced tomatoes","unit":"text","quantity":null,"preparation":"","originalText":"1 can (14 oz)"},{"name":"dry green lentils","unit":"cup","quantity":0.75,"preparation":"","originalText":"3/4 cup"},{"name":"white wine vinegar","unit":"tbsp","quantity":2,"preparation":"","originalText":"2 tbsp"},{"name":"fresh thyme","unit":"sprigs","quantity":12,"preparation":"","originalText":"12 sprigs"},{"name":"vegetable broth","unit":"cup","quantity":6,"preparation":"","originalText":"6 cups"},{"name":"fresh parsley","unit":"cup","quantity":0.5,"preparation":"","originalText":"1/2 cup"},{"name":"red pepper flakes","unit":"text","quantity":null,"preparation":"","originalText":"to taste"}],"baseServings":null,"instructions":"Open the source recipe for cooking directions. Serves 4–6; source serving range is unconfirmed for scaling. Vegan version omits the optional Parmesan topping."}]''';

void main() {
  final recipes = (jsonDecode(records) as List)
      .map((j) => Recipe.fromJson(Map<String, dynamic>.from(j)))
      .toList();
  final vegetarian = discoverRecipes(
    recipes,
    collection: RecipeCollection.vegetarian,
  );
  if (vegetarian.length != 4)
    throw StateError(
      'Vegetarian should include all four shared starter fixtures; got ${vegetarian.length}',
    );
  final vegan = discoverRecipes(recipes, collection: RecipeCollection.vegan);
  if (vegan.length != 2 ||
      !vegan.map((r) => r.id).toSet().containsAll({'vegan-01', 'vegan-03'}))
    throw StateError(
      'Vegan should include only the plant-based chilli and soup',
    );
  final edited = Recipe.fromJson({
    ...recipes.first.toJson(),
    'ingredients': [
      ...recipes.first.ingredients.map((i) => i.toJson()),
      const Ingredient(name: 'chicken').toJson(),
    ],
  });
  if (inCollection(edited, RecipeCollection.vegetarian))
    throw StateError('Ingredient edits must remove curated dietary labels');
  if (showVeganLabel(recipes.singleWhere((r) => r.id == 'vegan-03')))
    throw StateError(
      'Vegan soup title should not receive a duplicate Vegan badge',
    );
  if (!showVeganLabel(recipes.singleWhere((r) => r.id == 'vegan-01')))
    throw StateError('Chilli should retain its informative Vegan badge');
  print('PASS shared vegetarian/vegan filters and edited ingredient guard');
}
