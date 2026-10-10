import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_test_support.dart';

void main() {
  testWidgets('selected day survives navigation and window changes', (
    tester,
  ) async {
    await mountLayout(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('day-14')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final expected = '${now.year}-${now.month.toString().padLeft(2, '0')}-14';
    await navigate(tester, 'Recipes');
    await navigate(tester, 'Calendar');
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('calendar grid targets remain at least 48 pixels', (
    tester,
  ) async {
    await mountLayout(tester, const Size(390, 844));
    final target = tester.getRect(find.byKey(const ValueKey('day-14')));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
  });
  testWidgets('calendar panes do not split below their padded minimum widths', (
    tester,
  ) async {
    await mountLayout(tester, const Size(976, 900));
    final calendar = tester.getRect(
      find.byKey(const ValueKey('planner-calendar')),
    );
    final detail = tester.getRect(
      find.byKey(const ValueKey('planner-day-detail')),
    );
    expect(detail.top, greaterThan(calendar.bottom));
  });
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
