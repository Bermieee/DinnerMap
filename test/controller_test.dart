import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test('backup restore waits for queued edits and persists last', () async {
    final repository = DelayedRepository(
      PlannerSnapshot(
        entries: [
          PlanEntry(id: 'a', date: DateTime(2026, 1, 1), recipeId: 'r'),
        ],
        recipes: {'r': const Recipe(id: 'r', title: 'Dinner')},
      ),
    );
    final controller = PlannerController(repository);
    await Future<void>.delayed(Duration.zero);
    controller.updateEntry(
      controller.state.asData!.value.entries.first.copyWith(notes: 'old edit'),
    );
    await Future<void>.delayed(Duration.zero);
    const restored = PlannerSnapshot(entries: [], recipes: {}, revision: 20);
    final restoring = controller.importBackup(restored.encode());
    repository.firstSave.complete();
    await restoring;
    expect(repository.snapshot.revision, 20);
    expect(repository.snapshot.entries, isEmpty);
    expect(controller.state.asData!.value.revision, 20);
    controller.dispose();
  });
  test('invalid restore does not overwrite saved data', () async {
    final repository = DelayedRepository(
      const PlannerSnapshot(entries: [], recipes: {}, revision: 1),
    );
    final controller = PlannerController(repository);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      controller.importBackup('{"version":99}'),
      throwsFormatException,
    );
    expect(repository.writes, 0);
    controller.dispose();
  });
}
