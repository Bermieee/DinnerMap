import 'dart:convert';
import '../lib/data/planner_repository.dart';
import '../lib/features/planner/models.dart';
import '../lib/features/sync/shared_models.dart';
import '../lib/features/shopping/shopping_models.dart';

void check(bool v, String n) {
  if (!v) throw StateError(n);
  print('PASS $n');
}

void main() {
  const r = Recipe(id: 'r', title: 'Soup');
  final e = PlanEntry(id: 'day', date: DateTime(2026, 10, 9), recipeId: 'r');
  final s = PlannerSnapshot(entries: [e], recipes: {'r': r});
  final view = SharedView(s, {'entry:day': 4, 'recipe:r': 2});
  final commands = changesBetween(
    view,
    s.copyWith(entries: [e.copyWith(cooked: true)]),
  );
  check(
    commands.length == 1 && commands.first['op'] == 'entry',
    'one meal becomes one command',
  );
  check(commands.first['expectedRevision'] == 4, 'meal revision retained');
  check(
    !jsonEncode(commands).contains('recipes'),
    'no whole snapshot cloud save',
  );
  final changed = s.copyWith(
    recipes: {
      'r': r,
      'new': const Recipe(id: 'new', title: 'New'),
    },
  );
  check(
    changesBetween(view, changed).first['expectedRevision'] == -1,
    'new record uses create revision',
  );
  check(
    SharedView.decode(view.encode()).revisions['entry:day'] == 4,
    'cache revisions round trip',
  );
  final oldList = SavedShoppingList(
    start: DateTime(2026, 10, 9),
    weeks: 1,
    sourceRevision: 0,
    checked: {'m1'},
    manualItems: [const ManualItem(id: 'm1', name: 'Milk')],
  );
  final withManual = s.copyWith(list: oldList);
  final removed = oldList.copyWith(checked: {}, manualItems: []);
  final removal = changesBetween(
    SharedView(withManual, {}),
    withManual.copyWith(list: removed),
  );
  check(
    removal.length == 1 && removal.first['op'] == 'removeManual',
    'checked manual removal has no orphan check command',
  );
}
