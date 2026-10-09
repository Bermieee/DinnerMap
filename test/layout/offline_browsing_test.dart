import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinnermap/features/sync/shared_cache.dart';
import 'package:dinnermap/features/sync/shared_planner_controller.dart';
import '../sync/shared_controller_test.dart' show MemoryShared, tick;
import 'layout_test_support.dart';

void main() {
  testWidgets(
    'offline shared recipes can search while mutations are disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MemoryShared();
      final c = SharedPlannerController(
        repo,
        SharedCache(await SharedPreferences.getInstance()),
        'u',
        'h',
      );
      await tester.runAsync(tick);
      repo.events.add(false);
      await tester.runAsync(tick);
      await mountLayout(tester, const Size(390, 844), controller: c);
      await navigate(tester, 'Recipes');
      await tester.enterText(find.byType(TextField), 'Soup');
      await tester.pumpAndSettle();
      expect(find.text('Soup'), findsNWidgets(2));
      final add = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add recipe'),
      );
      expect(add.onPressed, isNull);
      await tester.tap(find.text('Soup').last);
      await tester.pumpAndSettle();
      expect(find.text('Ingredients'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Edit recipe'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
