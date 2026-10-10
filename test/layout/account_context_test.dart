import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/app.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import '../widget_test.dart' show MemoryRepository;
import 'layout_test_support.dart' show navigate;

void main() {
  testWidgets('replacing account context cannot save an old editor draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final contextIndex = StateProvider<int>((ref) => 0);
    final firstRepo = MemoryRepository(
      const PlannerSnapshot(
        entries: [],
        recipes: {'a': Recipe(id: 'a', title: 'First meal')},
      ),
    );
    final secondRepo = MemoryRepository(
      const PlannerSnapshot(
        entries: [],
        recipes: {'b': Recipe(id: 'b', title: 'Second meal')},
      ),
    );
    final first = PlannerController(firstRepo),
        second = PlannerController(secondRepo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(firstRepo),
          plannerFactoryProvider.overrideWith((ref) {
            final index = ref.watch(contextIndex);
            return () => index == 0 ? first : second;
          }),
        ],
        child: const DinnerMapApp(),
      ),
    );
    await tester.pumpAndSettle();
    await navigate(tester, 'Recipes');
    await tester.tap(find.text('Add recipe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Recipe name',
      ),
      'Old account draft',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DinnerMapShell)),
    );
    container.read(contextIndex.notifier).state = 1;
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(first.mounted, isFalse);
    expect(secondRepo.snapshot.recipes.keys, ['b']);
    expect(find.textContaining('Editing is unavailable'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Second meal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
