import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/planner_repository.dart';
import '../../layout/adaptive_page.dart';
import '../shopping/shopping_engine.dart';
import 'models.dart';
import 'planner_controller.dart';
import 'recipe_discovery.dart';
import 'recipe_filters.dart';

Future<Recipe?> chooseRecipe(
  BuildContext context,
  PlannerSnapshot snapshot,
) async => showDinnerMapDialog<Recipe>(
  context: context,
  builder: (_) => RecipePicker(snapshot: snapshot),
);

class RecipePicker extends StatefulWidget {
  final PlannerSnapshot snapshot;
  const RecipePicker({super.key, required this.snapshot});
  @override
  State<RecipePicker> createState() => _PickerState();
}

class _PickerState extends State<RecipePicker> {
  String search = '', region = '';
  RecipeCollection collection = RecipeCollection.all;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = discoverRecipes(
      widget.snapshot.recipes.values,
      query: search,
      region: region,
      collection: collection,
    );
    return AdaptiveAlertDialog(
      title: const Text('Choose a dinner'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipeFilters(
              search: searchController,
              regions: recipeRegions(widget.snapshot.recipes.values),
              region: region,
              collection: collection,
              onSearch: (v) => setState(() => search = v),
              onRegion: (v) => setState(() => region = v),
              onCollection: (v) => setState(() => collection = v),
              onClear: () => setState(() {
                searchController.clear();
                search = '';
                region = '';
                collection = RecipeCollection.all;
              }),
            ),
            const SizedBox(height: 12),
            Text('${recipes.length} matching recipes'),
            if (recipes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No matching recipes. Try another region or clear your filters.',
                ),
              ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(recipes[i].title),
                  subtitle: Text(
                    [
                      recipes[i].region,
                      if (inCollection(recipes[i], RecipeCollection.vegan))
                        'Vegan',
                      if (inCollection(recipes[i], RecipeCollection.mealPrep))
                        'Meal prep',
                    ].where((s) => s.isNotEmpty).join(' • '),
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(context, recipes[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<void> editRecipe(
  BuildContext context,
  WidgetRef ref, {
  Recipe? recipe,
}) async {
  final editingController = ref.read(plannerProvider.notifier);
  final name = TextEditingController(text: recipe?.title ?? '');
  final servings = TextEditingController(
    text: recipe?.baseServings?.toString() ?? '',
  );
  final ingredients = TextEditingController(
    text:
        recipe?.ingredients
            .map(
              (i) =>
                  '${i.name} | ${i.originalText.isNotEmpty ? i.originalText : '${i.quantity ?? ''} ${i.unit}'}${i.preparation.isEmpty ? '' : ' | ${i.preparation}'}',
            )
            .join('\n') ??
        '',
  );
  final instructions = TextEditingController(text: recipe?.instructions ?? '');
  String? error;
  await showDinnerMapDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AdaptiveAlertDialog(
        title: Text(recipe == null ? 'Add a recipe' : 'Edit recipe'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Recipe name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: servings,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText:
                        'Original recipe servings (leave blank if unknown)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ingredients,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Ingredients • one per line',
                    hintText:
                        'ground beef | 1.5 lb\nonion | 2\nsalt | to taste',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructions,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Directions / notes',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(servings.text);
              if (name.text.trim().isEmpty ||
                  (servings.text.trim().isNotEmpty &&
                      (n == null || n <= 0 || n > 100))) {
                setState(
                  () => error =
                      'Enter a name and a positive serving count, or leave servings blank.',
                );
                return;
              }
              final parsed = <Ingredient>[];
              for (final line
                  in ingredients.text
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)) {
                final parts = line.split('|');
                if ((parts.length != 2 && parts.length != 3) ||
                    parts[0].trim().isEmpty) {
                  setState(
                    () => error = 'Each ingredient needs a name | measurement.',
                  );
                  return;
                }
                final measure = parseMeasure(parts[1]);
                parsed.add(
                  Ingredient(
                    name: parts[0].trim(),
                    quantity: measure.quantity,
                    unit: measure.unit,
                    originalText: parts[1].trim(),
                    preparation: parts.length == 3 ? parts[2].trim() : '',
                  ),
                );
              }
              if (!editingController.mounted || !editingController.canEdit) {
                setState(
                  () => error =
                      'Editing is unavailable. Reconnect or reopen this recipe in the active household.',
                );
                return;
              }
              editingController.updateRecipe(
                Recipe(
                  id:
                      recipe?.id ??
                      'custom-${DateTime.now().microsecondsSinceEpoch}',
                  title: name.text.trim(),
                  baseServings: n,
                  ingredients: parsed,
                  instructions: instructions.text.trim(),
                  sourceUrl: recipe?.sourceUrl ?? '',
                  category: recipe?.category ?? 'favorite',
                  region: recipe?.region ?? 'Custom',
                  incomplete: recipe?.incomplete ?? false,
                ),
                expectedRecipe: recipe,
              );
              Navigator.pop(context);
            },
            child: const Text('Save recipe'),
          ),
        ],
      ),
    ),
  );
}

class RecipeScreen extends ConsumerStatefulWidget {
  final PlannerSnapshot snapshot;
  const RecipeScreen({super.key, required this.snapshot});
  @override
  ConsumerState<RecipeScreen> createState() => _RecipesState();
}

class _RecipesState extends ConsumerState<RecipeScreen> {
  String search = '', category = 'all', region = '';
  RecipeCollection collection = RecipeCollection.all;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool favorites = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final controller = ref.read(plannerProvider.notifier);
    final recipes = discoverRecipes(
      s.recipes.values,
      query: search,
      region: region,
      collection: collection,
      category: category,
      favoritesOnly: favorites,
      favorites: s.favorites,
    );
    return AdaptivePage(
      child: ListView(
        key: const PageStorageKey('recipes-scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Recipe library',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              FilledButton.icon(
                onPressed: controller.canEdit
                    ? () => editRecipe(context, ref)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add recipe'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${s.recipes.length} source-linked recipes • original quantities preserved',
          ),
          const SizedBox(height: 16),
          RecipeIdeas(
            counts: {
              for (final c in RecipeCollection.values)
                c: s.recipes.values.where((r) => inCollection(r, c)).length,
            },
            selected: collection,
            onSelected: (v) => setState(() {
              collection = v;
              category = 'all';
            }),
          ),
          const SizedBox(height: 16),
          RecipeFilters(
            search: searchController,
            regions: recipeRegions(s.recipes.values),
            region: region,
            collection: collection,
            onSearch: (v) => setState(() => search = v),
            onRegion: (v) => setState(() => region = v),
            onCollection: (v) => setState(() => collection = v),
            onClear: () => setState(() {
              searchController.clear();
              search = '';
              region = '';
              collection = RecipeCollection.all;
              category = 'all';
              favorites = false;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final c in [
                'all',
                'quick',
                'favorite',
                'smoked',
                'leftovers',
              ])
                ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  onSelected: (_) => setState(() => category = c),
                ),
              FilterChip(
                label: const Text('Favorites only'),
                selected: favorites,
                onSelected: (v) => setState(() => favorites = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('${recipes.length} matching recipes'),
          if (recipes.isEmpty) const Text('No matching recipes.'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = ((constraints.maxWidth + 12) / 292).floor().clamp(
                1,
                5,
              );
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: recipes
                    .map(
                      (r) => SizedBox(
                        width: width,
                        child: Card(
                          child: InkWell(
                            onTap: () => showRecipe(context, ref, r),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${r.region} • ${r.baseServings == null ? 'servings unknown' : 'serves ${r.baseServings}'}${s.avoided.contains(r.id) ? ' • avoided in shuffle' : ''}',
                                  ),
                                  if (inCollection(r, RecipeCollection.vegan))
                                    const Text('Vegan'),
                                  if (inCollection(
                                    r,
                                    RecipeCollection.mealPrep,
                                  ))
                                    const Text('Meal prep idea'),
                                  Row(
                                    children: [
                                      Icon(
                                        s.avoided.contains(r.id)
                                            ? Icons.block
                                            : Icons.restaurant,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Favorite',
                                        icon: Icon(
                                          s.favorites.contains(r.id)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                        ),
                                        onPressed: controller.canEdit
                                            ? () => controller.favorite(r.id)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showRecipe(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  final editingController = ref.read(plannerProvider.notifier);
  await showDinnerMapDialog<void>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, modalRef, _) {
        modalRef.watch(plannerProvider);
        final canEdit =
            editingController.mounted &&
            editingController.canEdit &&
            identical(
              modalRef.read(plannerProvider.notifier),
              editingController,
            );
        return AdaptiveAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${recipe.region} • ${recipe.baseServings == null ? 'Original amounts: serving count unconfirmed' : 'Serves ${recipe.baseServings}'}',
              ),
              const SizedBox(height: 16),
              if (recipeGuide(recipe) case final guide?) ...[
                if (guide['vegan'] == true)
                  const Text('Vegan • choose plant-based toppings'),
                if (guide['vegetarian'] == true && guide['vegan'] != true)
                  const Text('Vegetarian • use vegetarian cheese where listed'),
                if ((guide['mealPrep'] as String).isNotEmpty) ...[
                  Text(
                    'Meal prep idea',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(guide['mealPrep'] as String),
                ],
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: canEdit
                        ? () async {
                            Navigator.pop(context);
                            await editRecipe(context, ref, recipe: recipe);
                          }
                        : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit recipe'),
                  ),
                  OutlinedButton(
                    onPressed: canEdit
                        ? () {
                            if (editingController.mounted &&
                                editingController.canEdit)
                              editingController.avoid(recipe.id);
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Toggle shuffle avoidance'),
                  ),
                  if (recipe.sourceUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(recipe.sourceUrl);
                        if (uri != null &&
                            ['http', 'https'].contains(uri.scheme)) {
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open source: $e'),
                                ),
                              );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Cooking source'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Ingredients',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ...recipe.ingredients.map(
                (i) => ListTile(
                  dense: true,
                  title: Text(i.name),
                  subtitle: Text(
                    i.originalText.isEmpty
                        ? '${i.quantity ?? 'Review'} ${i.unit}'
                        : i.originalText,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(recipe.instructions),
              if (recipe.incomplete)
                const Text(
                  '\nIncomplete source ingredients. Consult the source before shopping.',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}
