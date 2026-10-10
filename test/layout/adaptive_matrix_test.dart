import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(360, 780),
    Size(600, 960),
    Size(800, 1280),
    Size(1280, 800),
    Size(1440, 900),
    Size(844, 390),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all pages at $size text scale $scale remain reachable', (
        tester,
      ) async {
        await mountLayout(
          tester,
          size,
          scale: scale,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        );
        expect(tester.takeException(), isNull);
        for (final page in ['Recipes', 'Shopping', 'Household', 'Calendar']) {
          await navigate(tester, page);
          expect(tester.takeException(), isNull, reason: page);
        }
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Takeout'),
          180,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        expect(find.text('Takeout').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'vertical hinge keeps calendar and detail in separate usable regions',
    (tester) async {
      const hinge = Rect.fromLTWH(650, 0, 24, 900);
      await mountLayout(
        tester,
        const Size(1200, 900),
        features: [
          const DisplayFeature(
            bounds: hinge,
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(find.byKey(const ValueKey('planner-day-detail')), findsOneWidget);
      final detail = tester.getRect(
        find.byKey(const ValueKey('planner-day-detail')),
      );
      expect(detail.left, greaterThanOrEqualTo(674));
      expect(detail.overlaps(hinge), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'horizontal hinge chooses largest region for navigation and content',
    (tester) async {
      const hinge = Rect.fromLTWH(0, 350, 800, 24);
      await mountLayout(
        tester,
        const Size(800, 1000),
        features: [
          const DisplayFeature(
            bounds: hinge,
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      final navigation = find.byType(NavigationBar).evaluate().isNotEmpty
          ? find.byType(NavigationBar)
          : find.byType(NavigationRail);
      expect(tester.getRect(navigation).overlaps(hinge), isFalse);
      expect(
        tester.getRect(find.text('What’s for dinner?')).top,
        greaterThanOrEqualTo(374),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
