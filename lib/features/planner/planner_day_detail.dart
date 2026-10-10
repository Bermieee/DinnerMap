import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../data/planner_repository.dart';
import 'models.dart';
import 'planner_controller.dart';
import 'recipe_screen.dart';

class PlannerDayDetail extends ConsumerWidget {
  final PlannerSnapshot snapshot;
  final DateTime selected;
  final DateTime? month;
  const PlannerDayDetail({
    super.key,
    required this.snapshot,
    required this.selected,
    this.month,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final controller = ref.read(plannerProvider.notifier);
    final entry = s.entries
        .where((e) => dateKey(e.date) == dateKey(selected))
        .firstOrNull;
    final recipe = s.recipes[entry?.recipeId];
    final start = month ?? DateTime(selected.year, selected.month);
    final days = DateTime(start.year, start.month + 1, 0).day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: controller.canEdit
                  ? () => controller.randomizeRange(selected, 7)
                  : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle 7 days'),
            ),
            OutlinedButton(
              onPressed: controller.canEdit
                  ? () => controller.randomizeRange(start, days)
                  : null,
              child: const Text('Shuffle month'),
            ),
            TextButton(
              onPressed: controller.canEdit ? controller.undo : null,
              child: const Text('Undo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateKey(selected),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  entry == null
                      ? 'Choose a dinner'
                      : entry.kind == EntryKind.takeout
                      ? 'Takeout night'
                      : entry.kind == EntryKind.leftovers
                      ? 'Leftovers night'
                      : recipe?.title ?? 'Missing recipe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: controller.canEdit
                          ? () async {
                              final chosen = await chooseRecipe(context, s);
                              if (chosen != null &&
                                  controller.mounted &&
                                  controller.canEdit)
                                controller.replaceMeal(
                                  entry ??
                                      PlanEntry(
                                        id: dateKey(selected),
                                        date: selected,
                                      ),
                                  chosen,
                                );
                            }
                          : null,
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(entry == null ? 'Plan meal' : 'Replace meal'),
                    ),
                    if (recipe != null && entry?.kind == EntryKind.recipe)
                      OutlinedButton(
                        onPressed: () => showRecipe(context, ref, recipe),
                        child: const Text('Recipe details'),
                      ),
                    OutlinedButton(
                      onPressed: controller.canEdit
                          ? () => controller.setEntryKind(
                              entry ??
                                  PlanEntry(
                                    id: dateKey(selected),
                                    date: selected,
                                  ),
                              EntryKind.takeout,
                            )
                          : null,
                      child: const Text('Takeout'),
                    ),
                    OutlinedButton(
                      onPressed: controller.canEdit
                          ? () => controller.setEntryKind(
                              entry ??
                                  PlanEntry(
                                    id: dateKey(selected),
                                    date: selected,
                                  ),
                              EntryKind.leftovers,
                            )
                          : null,
                      child: const Text('Leftovers'),
                    ),
                  ],
                ),
                if (entry != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Servings'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: entry.targetServings,
                        items:
                            [
                                  ...{
                                    1,
                                    2,
                                    3,
                                    4,
                                    5,
                                    6,
                                    7,
                                    8,
                                    10,
                                    12,
                                    entry.targetServings,
                                  },
                                ]
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n'),
                                  ),
                                )
                                .toList(),
                        onChanged: controller.canEdit
                            ? (n) {
                                if (n != null)
                                  controller.updateEntry(
                                    entry.copyWith(targetServings: n),
                                    expectedEntry: entry,
                                  );
                              }
                            : null,
                      ),

                      const Text('Cooked'),
                      Checkbox(
                        value: entry.cooked,
                        onChanged: controller.canEdit
                            ? (v) => controller.setCooked(entry, v ?? false)
                            : null,
                      ),
                    ],
                  ),
                  if (recipe?.baseServings == null &&
                      entry.kind == EntryKind.recipe)
                    const Text(
                      'Confirm the recipe’s base servings before quantities can scale.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  TextButton.icon(
                    onPressed: controller.canEdit
                        ? () async {
                            final text = await promptText(
                              context,
                              'Meal notes',
                              initial: entry.notes,
                              lines: 3,
                            );
                            if (text != null &&
                                controller.mounted &&
                                controller.canEdit)
                              controller.updateEntry(
                                entry.copyWith(notes: text),
                                expectedEntry: entry,
                              );
                          }
                        : null,
                    icon: const Icon(Icons.notes),
                    label: Text(
                      entry.notes.isEmpty ? 'Add notes' : entry.notes,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
