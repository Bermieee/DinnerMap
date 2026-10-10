import 'models.dart';

List<DateTime> monthDates(DateTime date) => [
  for (var day = 1; day <= DateTime(date.year, date.month + 1, 0).day; day++)
    DateTime(date.year, date.month, day),
];

List<PlanEntry> fillPlanRange(
  List<PlanEntry> entries,
  DateTime start,
  int days,
  String Function() chooseRecipe,
) {
  final occupied = entries.map((entry) => dateKey(entry.date)).toSet();
  return [
    ...entries,
    for (var i = 0; i < days; i++)
      if (!occupied.contains(
        dateKey(DateTime(start.year, start.month, start.day + i)),
      ))
        PlanEntry(
          id: 'day-${dateKey(DateTime(start.year, start.month, start.day + i))}',
          date: DateTime(start.year, start.month, start.day + i),
          recipeId: chooseRecipe(),
        ),
  ];
}
