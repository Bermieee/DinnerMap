import '../../layout/adaptive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/planner_repository.dart';
import '../planner/models.dart';
import '../planner/planner_controller.dart';
import 'shopping_models.dart';
import 'shopping_engine.dart';
import 'shopping_export.dart';
import 'shopping_actions.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  final PlannerSnapshot snapshot;
  const ShoppingScreen({super.key, required this.snapshot});
  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingState();
}

class _ShoppingState extends ConsumerState<ShoppingScreen> {
  DateTime? _start;
  int? _weeks;
  String unit = 'lb';
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final list = s.list;
    final start =
        _start ??
        list?.start ??
        s.entries.firstOrNull?.date ??
        dateOnly(DateTime.now());
    final weeks = _weeks ?? list?.weeks ?? 1;
    final controller = ref.read(plannerProvider.notifier);
    final groups = <String, List<ShoppingRow>>{};
    for (final row in list?.rows ?? <ShoppingRow>[]) {
      groups.putIfAbsent(groceryGroup(row.name), () => []).add(row);
    }
    return AdaptivePage(
      maxWidth: 800,
      child: ListView(
        key: const PageStorageKey('shopping-scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Shopping list',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'One combined list for every dinner in your selected weeks.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _start = date);
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(dateKey(start)),
              ),
              DropdownButton<int>(
                value: weeks,
                items: [
                  for (var n = 1; n <= 4; n++)
                    DropdownMenuItem(
                      value: n,
                      child: Text('$n week${n == 1 ? '' : 's'}'),
                    ),
                ],
                onChanged: (n) => setState(() => _weeks = n),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'lb', label: Text('Pounds')),
                  ButtonSegment(value: 'oz', label: Text('Ounces')),
                ],
                selected: {unit},
                onSelectionChanged: (v) => setState(() => unit = v.first),
              ),
              FilledButton.icon(
                onPressed: controller.canEdit
                    ? () => controller.generate(start, weeks)
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Generate list'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Choose your dates and generate a grocery list.'),
              ),
            ),
          if (list != null) ...[
            Text(
              'Saved list: ${dateKey(list.start)} • ${list.weeks} week(s) • ${list.rows.length + list.manualItems.length} items',
            ),
            if (s.revision != list.sourceRevision)
              Card(
                color: const Color(0xff493c22),
                child: ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Your meal plan changed'),
                  subtitle: const Text(
                    'Regenerate to update totals. Your manual items and matching checkoffs will stay.',
                  ),
                  trailing: IconButton(
                    onPressed: controller.canEdit
                        ? () => controller.generate(list.start, list.weeks)
                        : null,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: shoppingText(
                          list,
                          massUnit: unit,
                          pieceWeights: s.pieceWeights,
                        ),
                      ),
                    );
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Shopping list copied')),
                      );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy list'),
                ),
                OutlinedButton.icon(
                  onPressed: () => shareShopping(
                    context,
                    shoppingText(
                      list,
                      massUnit: unit,
                      pieceWeights: s.pieceWeights,
                    ),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share list'),
                ),
                OutlinedButton.icon(
                  onPressed: () => printShopping(
                    context,
                    shoppingText(
                      list,
                      massUnit: unit,
                      pieceWeights: s.pieceWeights,
                    ),
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('Print list'),
                ),

                OutlinedButton(
                  onPressed: () => saveText(
                    context,
                    shoppingText(
                      list,
                      massUnit: unit,
                      pieceWeights: s.pieceWeights,
                    ),
                    'dinnermap-shopping',
                    'txt',
                  ),
                  child: const Text('Export TXT'),
                ),
                OutlinedButton(
                  onPressed: () => saveText(
                    context,
                    shoppingCsv(
                      list,
                      massUnit: unit,
                      pieceWeights: s.pieceWeights,
                    ),
                    'dinnermap-shopping',
                    'csv',
                  ),
                  child: const Text('Export CSV'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.canEdit
                      ? () async {
                          final name = await promptText(
                            context,
                            'Add grocery item',
                          );
                          if (name != null &&
                              name.isNotEmpty &&
                              context.mounted) {
                            final amount = await promptText(
                              context,
                              'Amount (optional)',
                            );
                            if (controller.mounted && controller.canEdit)
                              controller.addManual(name, amount ?? '');
                          }
                        }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list.warnings.isNotEmpty)
              Card(
                color: const Color(0xff302a20),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  leading: const Icon(Icons.warning_amber, color: Colors.amber),
                  title: Text(
                    '${list.warnings.length} quantity / recipe notes',
                  ),
                  subtitle: const Text(
                    'Review before shopping • estimates are not exact weights',
                  ),
                  children: list.warnings
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(w),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  group.key,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...group.value.map((row) {
                final checked = list.checked.contains(row.key);
                final piece = s.pieceWeights[row.key];
                final weight = piece == null ? null : row.estimatedOz(piece);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: checked,
                          onChanged: controller.canEdit
                              ? (v) => controller.checkItem(row.key, v ?? false)
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            row.name,
                            style: TextStyle(
                              decoration: checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${rowAmount(row, unit)}${row.preparation.isEmpty ? '' : ' • ${row.preparation}'}${weight == null ? '' : '\nEstimated shopping weight: ${(unit == 'lb' ? weight / 16 : weight).toStringAsFixed(2)} $unit ($piece oz per piece)'}',
                          ),
                        ),
                        if (row.quantity != null &&
                            [
                              'count',
                              'large',
                              'medium',
                              'small',
                            ].contains(row.unit))
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: controller.canEdit
                                    ? () async {
                                        final text = await promptText(
                                          context,
                                          'Estimated ounces per piece',
                                          initial: piece?.toString() ?? '',
                                          hint: 'e.g. 6 for a chicken thigh',
                                        );
                                        final n = double.tryParse(text ?? '');
                                        if (n != null &&
                                            n.isFinite &&
                                            n > 0 &&
                                            n <= 48) {
                                          if (controller.mounted &&
                                              controller.canEdit)
                                            controller.setPieceWeight(
                                              row.key,
                                              n,
                                            );
                                        } else if (text != null &&
                                            context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Enter a weight greater than 0 and at most 48 oz.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.scale, size: 16),
                                label: const Text('Set weight estimate'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (list.manualItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Extra groceries',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...list.manualItems.map(
                (m) => Card(
                  child: Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: list.checked.contains(m.id),
                          onChanged: controller.canEdit
                              ? (v) => controller.checkItem(m.id, v ?? false)
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(m.name),
                          subtitle: Text(m.amount),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove manual item',
                        onPressed: controller.canEdit
                            ? () => controller.removeManual(m.id)
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (list.rows.isEmpty && list.manualItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No grocery ingredients in this date range. Check your calendar or add an item.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
