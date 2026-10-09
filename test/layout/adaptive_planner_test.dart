import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  testWidgets('wide calendar shows selected day beside calendar', (
    tester,
  ) async {
    await mountLayout(tester, const Size(1280, 800));
    final calendar = find.byKey(const ValueKey('planner-calendar'));
    final detail = find.byKey(const ValueKey('planner-day-detail'));
    expect(calendar, findsOneWidget);
    expect(detail, findsOneWidget);
    expect(
      tester.getRect(detail).left,
      greaterThan(tester.getRect(calendar).right),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow calendar uses actionable day list', (tester) async {
    await mountLayout(tester, const Size(320, 568));
    expect(find.byKey(const ValueKey('calendar-day-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
