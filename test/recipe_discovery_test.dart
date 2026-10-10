import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/planner/recipe_screen.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import 'package:dinnermap/features/planner/starter_recipes.dart'
    show loadRecipes;
import 'widget_test.dart' show MemoryRepository;

const chicken = Recipe(
  id: 'j',
  title: 'Chicken Bowl',
  region: 'Japanese',
  ingredients: [
    Ingredient(name: 'rice'),
    Ingredient(name: 'chicken'),
  ],
);
const soup = Recipe(
  id: 'g',
  title: 'Potato Soup',
  region: 'German',
  ingredients: [Ingredient(name: 'potato')],
);
const salad = Recipe(
  id: 's',
  title: 'Rice Salad',
  region: 'Japanese',
  ingredients: [Ingredient(name: 'rice')],
);
final snapshot = PlannerSnapshot(
  entries: const [],
  recipes: {'j': chicken, 'g': soup, 's': salad},
);

void main() {
  testWidgets(
    'library vegan collection combines with region and shows meal prep ideas',
    (tester) async {
      final recipes = loadRecipes(
        jsonDecode(File('assets/recipes.json').readAsStringSync()) as List,
      );
      final library = PlannerSnapshot(
        entries: const [],
        recipes: {for (final r in recipes) r.id: r},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(MemoryRepository(library)),
          ],
          child: MaterialApp(
            home: Scaffold(body: RecipeScreen(snapshot: library)),
          ),
        ),
      );
      await tester.tap(find.text('Explore food ideas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vegan').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sweet Potato & Bean Chilli'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sweet Potato & Bean Chilli'), findsOneWidget);
      expect(find.text('Easy Meatloaf'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('All regions'),
        -180,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('recipes-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All regions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indian').last);
      await tester.pumpAndSettle();
      expect(find.text('Sweet Potato & Bean Chilli'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Coconut Chickpea & Spinach Curry'),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('recipes-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Coconut Chickpea & Spinach Curry'), findsOneWidget);
      await tester.ensureVisible(find.text('Coconut Chickpea & Spinach Curry'));
      await tester.tap(find.text('Coconut Chickpea & Spinach Curry'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Prepare the curry as a batch'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dinner search finds an ingredient and a region', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecipePicker(snapshot: snapshot)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'potato');
    await tester.pumpAndSettle();
    expect(find.text('Potato Soup'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Japanese rice');
    await tester.pumpAndSettle();
    expect(find.text('Chicken Bowl'), findsOneWidget);
    expect(find.text('Rice Salad'), findsOneWidget);
    expect(find.text('Potato Soup'), findsNothing);
  });
  testWidgets('region filter narrows dinners and clearing restores selection', (
    tester,
  ) async {
    Recipe? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await chooseRecipe(context, snapshot);
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All regions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('German').last);
    await tester.pumpAndSettle();
    expect(find.text('Potato Soup'), findsOneWidget);
    expect(find.text('Chicken Bowl'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken Bowl'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'j');
  });
  testWidgets('picker stays reachable on narrow large-text windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: RecipePicker(snapshot: snapshot)),
      ),
    );
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
