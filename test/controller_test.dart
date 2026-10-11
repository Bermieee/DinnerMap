import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/planner/planner_controller.dart';

class DelayedRepository implements PlannerRepository {
  PlannerSnapshot snapshot;
  final firstSave = Completer<void>();
  int writes = 0;
  DelayedRepository(this.snapshot);
  @override
  Future<PlannerSnapshot?> load() async => snapshot;
  @override
  Future<void> save(PlannerSnapshot next) async {
    writes++;
    if (writes == 1) await firstSave.future;
    snapshot = next;
  }

  @override
  Future<String?> rawBackup() async => snapshot.encode();
}

class EmptyRepository implements PlannerRepository {
  @override
  Future<PlannerSnapshot?> load() async => null;
  @override
  Future<void> save(PlannerSnapshot snapshot) async {}
  @override
  Future<String?> rawBackup() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new plan covers the current local calendar month', () async {
    final before = DateTime.now();
    final controller = PlannerController(EmptyRepository(), autoLoad: false);
    await controller.load();
    final entries = controller.state.asData!.value.entries;
    final after = DateTime.now();
    final month = entries.first.date;
    expect(month.day, 1);
    expect(
      month.year == before.year && month.month == before.month ||
          month.year == after.year && month.month == after.month,
      isTrue,
    );
    expect(entries.length, DateTime(month.year, month.month + 1, 0).day);
    expect(entries.last.date.day, entries.length);
    controller.dispose();
  });
  test(
    'shuffle month fills missing dates and preserves non-recipe days',
    () async {
      final takeout = PlanEntry(
        id: 'takeout',
        date: DateTime(2028, 2, 10),
        kind: EntryKind.takeout,
        notes: 'Family night',
      );
      final outside = PlanEntry(
        id: 'outside',
        date: DateTime(2028, 3, 1),
        recipeId: 'r',
        cooked: true,
      );
      final repository = DelayedRepository(
        PlannerSnapshot(
          entries: [takeout, outside],
          recipes: {'r': const Recipe(id: 'r', title: 'Dinner')},
        ),
      );
      repository.firstSave.complete();
      final controller = PlannerController(repository, autoLoad: false);
      await controller.load();
      controller.randomizeRange(DateTime(2028, 2), 29);
      final entries = controller.state.asData!.value.entries;
      expect(entries.length, 30);
      expect(entries.where((entry) => entry.date.month == 2).length, 29);
      expect(entries.first.notes, 'Family night');
      expect(entries.first.kind, EntryKind.takeout);
      expect(entries[1].cooked, isTrue);
      controller.undo();
      expect(controller.state.asData!.value.entries.length, 2);
      controller.dispose();
    },
  );
  test('backup restore waits for queued edits and persists last', () async {
    final repository = DelayedRepository(
      PlannerSnapshot(
        entries: [
          PlanEntry(id: 'a', date: DateTime(2026, 1, 1), recipeId: 'r'),
        ],
        recipes: {'r': const Recipe(id: 'r', title: 'Dinner')},
      ),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    final controller = container.read(plannerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    controller.updateEntry(
      container
          .read(plannerProvider)
          .asData!
          .value
          .entries
          .first
          .copyWith(notes: 'old edit'),
    );
    await Future<void>.delayed(Duration.zero);
    const restored = PlannerSnapshot(entries: [], recipes: {}, revision: 20);
    final restoring = controller.importBackup(restored.encode());
    repository.firstSave.complete();
    await restoring;
    expect(repository.snapshot.revision, 20);
    expect(repository.snapshot.entries, isEmpty);
    expect(container.read(plannerProvider).asData!.value.revision, 20);
    container.dispose();
  });
  test('invalid restore does not overwrite saved data', () async {
    final repository = DelayedRepository(
      const PlannerSnapshot(entries: [], recipes: {}, revision: 1),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    final controller = container.read(plannerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      controller.importBackup('{"version":99}'),
      throwsFormatException,
    );
    expect(repository.writes, 0);
    container.dispose();
  });
}
