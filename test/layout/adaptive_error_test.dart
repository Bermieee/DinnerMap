import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/app.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import 'layout_test_support.dart' show navigate;

class BrokenRepository implements PlannerRepository {
  @override
  Future<PlannerSnapshot?> load() async => throw const FormatException(
    'Saved recipe data cannot be decoded. The original backup has been kept so it can be exported and repaired.',
  );
  @override
  Future<void> save(PlannerSnapshot snapshot) async {}
  @override
  Future<String?> rawBackup() async => 'broken saved data';
}

void main() {
  testWidgets('load errors remain scrollable on a small large-text window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(BrokenRepository())],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DinnerMapShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await navigate(tester, 'Household');
    expect(find.text('Your household'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
