import 'dart:ui' show DisplayFeature;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/app.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import '../widget_test.dart' show MemoryRepository;

Future<MemoryRepository> mountLayout(
  WidgetTester tester,
  Size size, {
  double scale = 1,
  List<DisplayFeature> features = const [],
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets? keyboard,
  PlannerController? controller,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final today = dateOnly(DateTime.now());
  final repo = MemoryRepository(
    PlannerSnapshot(
      entries: [PlanEntry(id: 'a', date: today, recipeId: 'r')],
      recipes: {
        'r': const Recipe(
          id: 'r',
          title: 'Chicken Dinner',
          baseServings: 4,
          ingredients: [Ingredient(name: 'chicken', quantity: 1, unit: 'lb')],
        ),
        's': const Recipe(id: 's', title: 'Soup', baseServings: 4),
      },
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        if (controller != null)
          plannerFactoryProvider.overrideWithValue(() => controller),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              displayFeatures: features,
              padding: padding,
              viewInsets: keyboard ?? MediaQuery.of(context).viewInsets,
            ),
            child: const DinnerMapShell(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> navigate(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
