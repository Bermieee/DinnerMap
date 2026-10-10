import 'package:flutter/material.dart';
import 'recipe_discovery.dart';

class RecipeFilters extends StatelessWidget {
  final TextEditingController search;
  final List<String> regions;
  final String region;
  final RecipeCollection collection;
  final ValueChanged<String> onSearch, onRegion;
  final ValueChanged<RecipeCollection> onCollection;
  final VoidCallback onClear;
  const RecipeFilters({
    super.key,
    required this.search,
    required this.regions,
    required this.region,
    required this.collection,
    required this.onSearch,
    required this.onRegion,
    required this.onCollection,
    required this.onClear,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: search,
        onChanged: onSearch,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search name, region or ingredient',
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 460
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: regions.contains(region) ? region : '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All regions'),
                        ),
                        for (final r in regions)
                          DropdownMenuItem(
                            value: r,
                            child: Text(r, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) onRegion(v);
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Food ideas',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RecipeCollection>(
                      isExpanded: true,
                      value: collection,
                      items: [
                        for (final c in RecipeCollection.values)
                          DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) onCollection(v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      if (search.text.isNotEmpty ||
          region.isNotEmpty ||
          collection != RecipeCollection.all)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onClear,
            child: const Text('Clear filters'),
          ),
        ),
    ],
  );
}

class RecipeIdeas extends StatelessWidget {
  final Map<RecipeCollection, int> counts;
  final RecipeCollection selected;
  final ValueChanged<RecipeCollection> onSelected;
  const RecipeIdeas({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Explore food ideas', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in RecipeCollection.values.where(
              (c) => c != RecipeCollection.all,
            ))
              SizedBox(
                width: constraints.maxWidth < 700
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3,
                child: Card(
                  color: selected == c
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Semantics(
                    button: true,
                    selected: selected == c,
                    child: InkWell(
                      onTap: () =>
                          onSelected(selected == c ? RecipeCollection.all : c),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              c == RecipeCollection.mealPrep
                                  ? Icons.lunch_dining_outlined
                                  : Icons.eco_outlined,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${counts[c] ?? 0} recipes'),
                            Text(switch (c) {
                              RecipeCollection.vegan =>
                                'Plant-based dinners and vegan toppings.',
                              RecipeCollection.vegetarian =>
                                'Meat-free ideas, including eggs and dairy.',
                              RecipeCollection.mealPrep =>
                                'Batch dinners and portioning ideas.',
                              RecipeCollection.all => '',
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Curated ideas. Check ingredient labels and substitutions; use vegetarian cheese where listed.',
      ),
    ],
  );
}
