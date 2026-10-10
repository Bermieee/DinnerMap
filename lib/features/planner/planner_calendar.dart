import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/planner_repository.dart';
import 'models.dart';

class PlannerCalendar extends StatelessWidget {
  final PlannerSnapshot snapshot;
  final DateTime month, selected;
  final ValueChanged<DateTime> onSelected, onMonthChanged;
  const PlannerCalendar({
    super.key,
    required this.snapshot,
    required this.month,
    required this.selected,
    required this.onSelected,
    required this.onMonthChanged,
  });
  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7;
    String title(DateTime date) {
      final entry = snapshot.entries
          .where((e) => dateKey(e.date) == dateKey(date))
          .firstOrNull;
      if (entry == null) return 'Plan meal';
      if (entry.kind == EntryKind.takeout) return 'Takeout';
      if (entry.kind == EntryKind.leftovers) return 'Leftovers';
      return snapshot.recipes[entry.recipeId]?.title ?? 'Missing recipe';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              label: Text(
                '${snapshot.entries.where((e) => e.kind == EntryKind.recipe).length} planned meals',
              ),
            ),
            Chip(
              label: Text(
                '${snapshot.entries.where((e) => e.cooked).length} cooked',
              ),
            ),
            Chip(label: Text('${snapshot.recipes.length} recipes')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
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
                  onMonthChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            if ((constraints.maxWidth - 30) / 7 < 48) {
              return Column(
                key: const ValueKey('calendar-day-list'),
                children: [
                  for (var day = 1; day <= days; day++)
                    ListTile(
                      key: ValueKey('day-$day'),
                      selected:
                          dateKey(selected) ==
                          dateKey(DateTime(month.year, month.month, day)),
                      title: Text(
                        '$day • ${title(DateTime(month.year, month.month, day))}',
                      ),
                      onTap: () =>
                          onSelected(DateTime(month.year, month.month, day)),
                    ),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    for (final day in [
                      'Sun',
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                    ])
                      Expanded(
                        child: Center(
                          child: Text(
                            day,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
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
                    mainAxisExtent: 104 * math.max(1, scale),
                  ),
                  itemBuilder: (context, index) {
                    final day = index - offset + 1;
                    if (day < 1 || day > days) return const SizedBox();
                    final date = DateTime(month.year, month.month, day);
                    final entry = snapshot.entries
                        .where((e) => dateKey(e.date) == dateKey(date))
                        .firstOrNull;
                    final label = title(date);
                    return Semantics(
                      label:
                          '${dateKey(date)}, $label${entry?.cooked == true ? ', cooked' : ''}',
                      button: true,
                      selected: dateKey(selected) == dateKey(date),
                      excludeSemantics: true,
                      child: Material(
                        color: dateKey(selected) == dateKey(date)
                            ? const Color(0xff243965)
                            : const Color(0xff182231),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: ValueKey('day-$day'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelected(date),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$day'),
                                const SizedBox(height: 5),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                if (entry?.cooked == true)
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.greenAccent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
