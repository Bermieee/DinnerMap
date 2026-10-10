import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  testWidgets('open editor moves to usable fold region without losing draft', (
    tester,
  ) async {
    final features = <DisplayFeature>[];
    await mountLayout(tester, const Size(390, 844), features: features);
    await navigate(tester, 'Recipes');
    await tester.tap(find.text('Add recipe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Recipe name',
      ),
      'Fold draft',
    );
    const hinge = Rect.fromLTWH(500, 0, 24, 900);
    features.add(
      const DisplayFeature(
        bounds: hinge,
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    );
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.text('Fold draft'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Cancel')).overlaps(hinge), isFalse);
    expect(tester.getRect(find.text('Cancel')).left, greaterThanOrEqualTo(524));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editor draft survives resize and keyboard actions remain reachable',
    (tester) async {
      await mountLayout(tester, const Size(390, 844));
      await navigate(tester, 'Recipes');
      await tester.tap(find.text('Add recipe'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Recipe name',
        ),
        'My draft dinner',
      );
      tester.view.physicalSize = const Size(844, 390);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('My draft dinner'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
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
