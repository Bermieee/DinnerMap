import '../lib/features/planner/models.dart';
import '../lib/features/planner/month_plan.dart';

void main() {
  for (final (year, month, days) in [
    (2026, 2, 28),
    (2028, 2, 29),
    (2026, 4, 30),
    (2026, 10, 31),
    (2026, 12, 31),
  ]) {
    final dates = monthDates(DateTime(year, month, 17));
    if (dates.length != days ||
        dates.first.day != 1 ||
        dates.last.day != days ||
        dates.any((date) => date.month != month))
      throw StateError('Month $year-$month');
  }
  final kept = PlanEntry(
    id: 'saved',
    date: DateTime(2028, 2, 10),
    kind: EntryKind.takeout,
    notes: 'keep',
  );
  final outside = PlanEntry(
    id: 'outside',
    date: DateTime(2028, 3, 1),
    recipeId: 'old',
  );
  final entries = fillPlanRange(
    [kept, outside],
    DateTime(2028, 2),
    29,
    () => 'r',
  );
  if (entries.length != 30 ||
      !identical(entries.first, kept) ||
      !identical(entries[1], outside) ||
      entries.map((e) => dateKey(e.date)).toSet().length != 30)
    throw StateError('Preserve existing and fill gaps');
  if (fillPlanRange(entries, DateTime(2028, 2), 29, () => 'r').length != 30)
    throw StateError('Idempotent fill');
  print('PASS 7 month plan checks');
}
