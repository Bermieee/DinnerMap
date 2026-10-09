import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
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
