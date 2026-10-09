import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  testWidgets(
    'editor draft survives resize and keyboard actions remain reachable',
    (tester) async {
      await mountLayout(tester, const Size(390, 844));
      await navigate(tester, 'Recipes');
      await tester.tap(find.text('Add recipe'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'My draft dinner');
      tester.view.physicalSize = const Size(844, 390);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('My draft dinner'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('large recipe window uses responsive cards', (tester) async {
    await mountLayout(tester, const Size(1280, 800));
    await navigate(tester, 'Recipes');
    final chicken = tester.getRect(find.text('Chicken Dinner'));
    final soup = tester.getRect(find.text('Soup'));
    expect(soup.top, chicken.top);
    expect(soup.left, greaterThan(chicken.left));
  });
}
