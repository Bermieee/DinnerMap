import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  testWidgets('calendar scroll position survives tab changes', (tester) async {
    await mountLayout(tester, const Size(320, 568));
    final page = find.byKey(const PageStorageKey('planner-scroll'));
    final scroll = find
        .descendant(of: page, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Takeout'),
      180,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scroll).position.pixels;
    expect(offset, greaterThan(0));
    await navigate(tester, 'Recipes');
    await navigate(tester, 'Calendar');
    expect(
      tester.state<ScrollableState>(scroll).position.pixels,
      closeTo(offset, 1),
    );
    expect(find.text('Takeout').hitTestable(), findsOneWidget);
  });
  testWidgets('shopping dates and weeks survive navigation', (tester) async {
    await mountLayout(tester, const Size(390, 844));
    await navigate(tester, 'Shopping');
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 weeks').last);
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final initial =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await tester.tap(find.text(initial));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await navigate(tester, 'Calendar');
    await navigate(tester, 'Shopping');
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      3,
    );
    expect(
      find.text('${now.year}-${now.month.toString().padLeft(2, '0')}-20'),
      findsOneWidget,
    );
  });
  testWidgets(
    '600 width uses rail and short landscape uses bottom navigation',
    (tester) async {
      await mountLayout(tester, const Size(600, 960));
      expect(find.byType(NavigationRail), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testWidgets('recipe search survives tab changes and resize', (tester) async {
    await mountLayout(tester, const Size(390, 844));
    await navigate(tester, 'Recipes');
    await tester.enterText(find.byType(TextField), 'Soup');
    await tester.pumpAndSettle();
    await navigate(tester, 'Shopping');
    await navigate(tester, 'Recipes');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Soup',
    );
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Soup',
    );
    expect(find.text('Chicken Dinner'), findsNothing);
  });
  testWidgets('shopping options survive tab changes', (tester) async {
    await mountLayout(tester, const Size(390, 844));
    await navigate(tester, 'Shopping');
    await tester.tap(find.text('Ounces'));
    await tester.pumpAndSettle();
    await navigate(tester, 'Calendar');
    await navigate(tester, 'Shopping');
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'oz'},
    );
  });
}
