import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/planner_repository.dart';
import '../shopping/shopping_engine.dart';
import 'models.dart';
import 'planner_controller.dart';

Future<Recipe?> chooseRecipe(
  BuildContext context,
  PlannerSnapshot snapshot,
) async => showDialog<Recipe>(
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
  String search = '';
  @override
  Widget build(BuildContext context) {
    final recipes = widget.snapshot.recipes.values
        .where((r) => r.title.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Choose a dinner'),
      content: SizedBox(
        width: 600,
        height: 440,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => search = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search recipes',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(recipes[i].title),
                  subtitle: Text(recipes[i].region),
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
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
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
                  (servings.text.trim().isNotEmpty && (n == null || n <= 0))) {
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
              ref
                  .read(plannerProvider.notifier)
                  .updateRecipe(
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
  String search = '', category = 'all';
  bool favorites = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final recipes = s.recipes.values
        .where(
          (r) =>
              r.title.toLowerCase().contains(search.toLowerCase()) &&
              (category == 'all' || r.category == category) &&
              (!favorites || s.favorites.contains(r.id)),
        )
        .toList();
    return ListView(
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
              onPressed: () => editRecipe(context, ref),
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
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search your dinners',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final c in ['all', 'quick', 'favorite', 'smoked', 'leftovers'])
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
        if (recipes.isEmpty) const Text('No matching recipes.'),
        ...recipes.map(
          (r) => Card(
            child: ListTile(
              leading: Icon(
                s.avoided.contains(r.id) ? Icons.block : Icons.restaurant,
              ),
              title: Text(r.title),
              subtitle: Text(
                '${r.region} • ${r.baseServings == null ? 'servings unknown' : 'serves ${r.baseServings}'}${s.avoided.contains(r.id) ? ' • avoided in shuffle' : ''}',
              ),
              trailing: IconButton(
                tooltip: 'Favorite',
                icon: Icon(
                  s.favorites.contains(r.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () =>
                    ref.read(plannerProvider.notifier).favorite(r.id),
              ),
              onTap: () => showRecipe(context, ref, r),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showRecipe(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.8,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.all(24),
      children: [
        Text(recipe.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${recipe.region} • ${recipe.baseServings == null ? 'Original amounts: serving count unconfirmed' : 'Serves ${recipe.baseServings}'}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await editRecipe(context, ref, recipe: recipe);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit recipe'),
            ),
            OutlinedButton(
              onPressed: () {
                ref.read(plannerProvider.notifier).avoid(recipe.id);
                Navigator.pop(context);
              },
              child: const Text('Toggle shuffle avoidance'),
            ),
            if (recipe.sourceUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(recipe.sourceUrl);
                  if (uri != null && ['http', 'https'].contains(uri.scheme)) {
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open source: $e')),
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
        Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
        ...recipe.ingredients.map(
          (i) => ListTile(
            dense: true,
            title: Text(i.name),
            trailing: Text(
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
  ),
);
