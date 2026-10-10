import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureType,
        DisplayFeatureState,
        SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinnermap/features/sync/shared_cache.dart';
import 'package:dinnermap/features/sync/shared_planner_controller.dart';
import '../sync/shared_controller_test.dart' show MemoryShared, tick;
import 'layout_test_support.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/app.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';
import 'package:dinnermap/features/household/account_controller.dart';
import 'package:dinnermap/features/household/account_models.dart';
import 'package:dinnermap/features/household/account_providers.dart';
import '../household/household_screen_test.dart' show TestAccounts;
import '../widget_test.dart' show MemoryRepository;

void main() {
  for (final action in ['Import', 'Leave', 'Date']) {
    testWidgets('old $action dialog cannot act after account replacement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final firstRepo = RecordingShared(), secondRepo = RecordingShared();
      final cache = SharedCache(await SharedPreferences.getInstance());
      final first = SharedPlannerController(firstRepo, cache, 'a', 'ha');
      final second = SharedPlannerController(secondRepo, cache, 'b', 'hb');
      await tester.runAsync(tick);
      final accounts = RecordingAccounts();
      final account = AccountController(accounts);
      final index = StateProvider<int>((ref) => 0);
      AccountState state(int n) => AccountState(
        session: AccountSession(n == 0 ? 'a' : 'b', 'test@example.com', true),
        household: Household(n == 0 ? 'ha' : 'hb', 'Family'),
      );
      account.state = state(0);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(
              MemoryRepository(firstRepo.current.snapshot),
            ),
            accountControllerProvider.overrideWithValue(account),
            accountStateProvider.overrideWith(
              (ref) => Stream.value(state(ref.watch(index))),
            ),
            activeHouseholdProvider.overrideWith(
              (ref) => (
                userId: ref.watch(index) == 0 ? 'a' : 'b',
                householdId: ref.watch(index) == 0 ? 'ha' : 'hb',
              ),
            ),
            plannerFactoryProvider.overrideWith(
              (ref) => ref.watch(index) == 0 ? () => first : () => second,
            ),
          ],
          child: const DinnerMapApp(),
        ),
      );
      await tester.pumpAndSettle();
      if (action == 'Date') {
        await navigate(tester, 'Shopping');
        await tester.tap(find.byIcon(Icons.calendar_today));
      } else {
        await navigate(tester, 'Household');
        final label = action == 'Import'
            ? 'Import local plan into empty household'
            : 'Leave household';
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
      }
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DinnerMapShell)),
      );
      account.state = state(1);
      container.read(index.notifier).state = 1;
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(action == 'Date' ? 'OK' : action).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(action == 'Date' ? 'OK' : action).last);
      await tester.pumpAndSettle();
      expect(firstRepo.imports + secondRepo.imports, 0);
      expect(accounts.leaves, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
    });
  }
  testWidgets('calendar days expose screen reader activation', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await mountLayout(tester, const Size(390, 844));
    final node = tester.getSemantics(find.byKey(const ValueKey('day-14')));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });
  testWidgets('single page uses larger asymmetric fold region', (tester) async {
    await mountLayout(
      tester,
      const Size(1600, 900),
      features: [
        const DisplayFeature(
          bounds: Rect.fromLTWH(700, 0, 24, 900),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    await navigate(tester, 'Recipes');
    expect(
      tester.getRect(find.byType(TextField)).left,
      greaterThanOrEqualTo(724),
    );
  });
  testWidgets('offline main content stays reachable above landscape keyboard', (
    tester,
  ) async {
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
    await mountLayout(
      tester,
      const Size(844, 390),
      keyboard: const EdgeInsets.only(bottom: 250),
      controller: c,
    );
    expect(tester.takeException(), isNull);
    await navigate(tester, 'Recipes');
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(TextField));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(140));
    await tester.enterText(find.byType(TextField), 'Soup');
    await tester.pumpAndSettle();
    expect(find.text('Soup'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('offline conflict reapply preserves proposed edit', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = MemoryShared();
    final c = SharedPlannerController(
      repo,
      SharedCache(await SharedPreferences.getInstance()),
      'u',
      'h',
    );
    await tick();
    repo.conflict = true;
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    final proposal = c.conflictChanges;
    expect(proposal, isNotNull);
    repo.events.add(false);
    await tick();
    final count = repo.requests.length;
    await c.reapplyConflict();
    expect(c.conflictChanges, same(proposal));
    expect(repo.requests.length, count);
    c.dispose();
  });
}

class RecordingShared extends MemoryShared {
  int imports = 0;
  @override
  Future<void> importLocal(PlannerSnapshot snapshot) async {
    imports++;
  }
}

class RecordingAccounts extends TestAccounts {
  int leaves = 0;
  @override
  Future<void> leaveHousehold() async {
    leaves++;
  }
}
