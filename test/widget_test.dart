import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/app.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';

class MemoryRepository implements PlannerRepository {
  PlannerSnapshot snapshot;
  MemoryRepository(this.snapshot);
  @override
  Future<PlannerSnapshot?> load() async => snapshot;
  @override
  Future<void> save(PlannerSnapshot s) async {
    snapshot = s;
  }

  @override
  Future<String?> rawBackup() async => snapshot.encode();
}

void main() {
  Future<MemoryRepository> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime.now();
    final repo = MemoryRepository(
      PlannerSnapshot(
        entries: [
          PlanEntry(
            id: 'a',
            date: DateTime(date.year, date.month, date.day),
            recipeId: 'r',
          ),
        ],
        recipes: {
          'soup': const Recipe(id: 'soup', title: 'Soup', baseServings: 4),
          'r': const Recipe(
            id: 'r',
            title: 'Chicken Dinner',
            baseServings: 4,
            ingredients: [Ingredient(name: 'chicken', quantity: 1, unit: 'lb')],
          ),
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const DinnerMapApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('mobile navigation and one week grocery generation', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    expect(find.text('LOCAL DEMO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate list'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('chicken'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('chicken'), findsOneWidget);
    expect(find.text('1 lb'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop calendar has no overflow', (tester) async {
    await mount(tester, const Size(1280, 900));
    expect(find.text('What’s for dinner?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement, undo and takeout exclude grocery ingredients', (
    tester,
  ) async {
    final repo = await mount(tester, const Size(390, 844));
    await tester.scrollUntilVisible(
      find.text('Replace meal'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Replace meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soup'));
    await tester.pumpAndSettle();
    expect(repo.snapshot.entries.single.recipeId, 'soup');
    await tester.ensureVisible(find.text('Undo'));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.snapshot.entries.single.recipeId, 'r');
    await tester.ensureVisible(find.text('Takeout'));
    await tester.tap(find.text('Takeout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate list'));
    await tester.pumpAndSettle();
    expect(repo.snapshot.list!.rows, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
