import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/planner_repository.dart';
import 'models.dart';
import 'planner_controller.dart';
import 'recipe_screen.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  final PlannerSnapshot snapshot;
  const PlannerScreen({super.key, required this.snapshot});
  @override
  ConsumerState<PlannerScreen> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<PlannerScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final controller = ref.read(plannerProvider.notifier);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7;
    final entry = s.entries
        .where((e) => dateKey(e.date) == dateKey(selected))
        .firstOrNull;
    final recipe = s.recipes[entry?.recipeId];
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.all(mobile ? 12 : 24),
      children: [
        Text(
          'What’s for dinner?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text('Plan your meals. Cook confidently.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.restaurant, size: 18),
              label: Text(
                '${s.entries.where((e) => e.kind == EntryKind.recipe).length} planned meals',
              ),
            ),
            Chip(
              avatar: const Icon(Icons.check_circle_outline, size: 18),
              label: Text('${s.entries.where((e) => e.cooked).length} cooked'),
            ),
            Chip(label: Text('${s.recipes.length} recipes')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
              Expanded(
                child: Center(
                  child: Text(d, style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ((days + offset) / 7).ceil() * 7,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: mobile ? 82 : 104,
          ),
          itemBuilder: (context, i) {
            final day = i - offset + 1;
            if (day < 1 || day > days) return const SizedBox();
            final date = DateTime(month.year, month.month, day);
            final e = s.entries
                .where((e) => dateKey(e.date) == dateKey(date))
                .firstOrNull;
            final r = s.recipes[e?.recipeId];
            final active = dateKey(selected) == dateKey(date);
            final title = e == null
                ? 'Plan meal'
                : e.kind == EntryKind.takeout
                ? 'Takeout'
                : e.kind == EntryKind.leftovers
                ? 'Leftovers'
                : r?.title ?? 'Missing recipe';
            return Material(
              color: active ? const Color(0xff243965) : const Color(0xff182231),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => selected = date),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('$day'),
                          if (e?.cooked == true)
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: mobile ? 9 : 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => controller.randomizeRange(selected, 7),
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle 7 days'),
            ),
            OutlinedButton(
              onPressed: () => controller.randomizeRange(month, days),
              child: const Text('Shuffle month'),
            ),
            TextButton(onPressed: controller.undo, child: const Text('Undo')),
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
                      onPressed: () async {
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
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(entry == null ? 'Plan meal' : 'Replace meal'),
                    ),
                    if (recipe != null && entry?.kind == EntryKind.recipe)
                      OutlinedButton(
                        onPressed: () => showRecipe(context, ref, recipe),
                        child: const Text('Recipe details'),
                      ),
                    OutlinedButton(
                      onPressed: () => controller.setEntryKind(
                        entry ??
                            PlanEntry(id: dateKey(selected), date: selected),
                        EntryKind.takeout,
                      ),
                      child: const Text('Takeout'),
                    ),
                    OutlinedButton(
                      onPressed: () => controller.setEntryKind(
                        entry ??
                            PlanEntry(id: dateKey(selected), date: selected),
                        EntryKind.leftovers,
                      ),
                      child: const Text('Leftovers'),
                    ),
                  ],
                ),
                if (entry != null) ...[
                  const SizedBox(height: 12),
                  Row(
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
                        onChanged: (n) {
                          if (n != null)
                            controller.updateEntry(
                              entry.copyWith(targetServings: n),
                              expectedEntry: entry,
                            );
                        },
                      ),
                      const Spacer(),
                      const Text('Cooked'),
                      Checkbox(
                        value: entry.cooked,
                        onChanged: (v) =>
                            controller.setCooked(entry, v ?? false),
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
                    onPressed: () async {
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
                    },
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
