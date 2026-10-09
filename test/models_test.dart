import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/features/planner/models.dart';

void main() {
  test('recipe round trip retains unknown servings and quantities', () {
    final r = Recipe(
      id: 'a',
      title: 'Dinner',
      ingredients: [Ingredient(name: 'salt', originalText: 'to taste')],
    );
    final restored = Recipe.fromJson(r.toJson());
    expect(restored.baseServings, isNull);
    expect(restored.ingredients.first.quantity, isNull);
    expect(restored.ingredients.first.originalText, 'to taste');
  });
  test('date round trip is date only across a year boundary', () {
    final e = PlanEntry(
      id: 'x',
      date: DateTime(2027, 1, 1),
      kind: EntryKind.takeout,
    );
    expect(PlanEntry.fromJson(e.toJson()).date, DateTime(2027, 1, 1));
    expect(e.toJson()['date'], '2027-01-01');
  });
}
