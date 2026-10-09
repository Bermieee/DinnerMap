import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinnermap/data/planner_repository.dart';
import 'package:dinnermap/features/planner/models.dart';
import 'package:dinnermap/features/sync/shared_cache.dart';
import 'package:dinnermap/features/sync/shared_models.dart';
import 'package:dinnermap/features/sync/shared_repository.dart';
import 'package:dinnermap/features/sync/shared_planner_controller.dart';

class MemoryShared implements SharedRepository {
  final events = StreamController<bool>.broadcast();
  late SharedView current;
  List<Map<String, dynamic>>? sent;
  bool conflict = false, uncertain = false, regenConflict = false;
  final requests = <String>[];
  Completer<SharedView>? pending, delayedFetch;
  MemoryShared() {
    final e = PlanEntry(id: 'd', date: DateTime(2026, 10, 9), recipeId: 'r');
    current = SharedView(
      PlannerSnapshot(
        entries: [e],
        recipes: {'r': const Recipe(id: 'r', title: 'Soup')},
      ),
      {'entry:d': 0, 'recipe:r': 0},
    );
  }
  @override
  Future<SharedView> fetch() async =>
      delayedFetch == null ? current : delayedFetch!.future;
  @override
  Future<SharedView> apply(
    String requestId,
    List<Map<String, dynamic>> changes,
  ) async {
    sent = changes;
    requests.add(requestId);
    if (uncertain)
      throw const SharedUnavailable('Unknown result', uncertain: true);
    if (conflict) throw const SharedConflict('Changed');
    if (pending != null) return pending!.future;
    final e = PlanEntry.fromJson(
      changes.first['value'] as Map<String, dynamic>,
    );
    current = SharedView(current.snapshot.copyWith(entries: [e]), {
      'entry:d': 1,
      'recipe:r': 0,
    });
    return current;
  }

  @override
  Future<SharedView> regenerate(
    String id,
    int revision,
    DateTime start,
    int weeks,
    List<Map<String, dynamic>> rows,
    List<String> warnings,
  ) async {
    if (regenConflict) throw const SharedConflict('Calendar changed');
    return current;
  }

  @override
  Future<void> importLocal(PlannerSnapshot s) async {}
  @override
  Stream<bool> watchConnection() => events.stream;
  @override
  Future<void> dispose() async {
    await events.close();
  }
}

Future<void> tick() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  test('offline commands never reach transport', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedCache(await SharedPreferences.getInstance());
    final repo = MemoryShared();
    final c = SharedPlannerController(repo, cache, 'u', 'h');
    await tick();
    repo.events.add(false);
    await tick();
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    expect(repo.sent, isNull);
    expect(c.canEdit, isFalse);
    c.dispose();
  });
  test('revision conflict retains proposed meal and reloads current', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedCache(await SharedPreferences.getInstance());
    final repo = MemoryShared();
    final c = SharedPlannerController(repo, cache, 'u', 'h');
    await tick();
    repo.conflict = true;
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    expect(c.conflictChanges!.first['value']['cooked'], isTrue);
    expect(c.view!.snapshot.entries.first.cooked, isFalse);
    expect(c.canEdit, isFalse);
    await c.discardConflict();
    expect(c.canEdit, isTrue);
    c.dispose();
  });
  test('late submitted reply cannot restore disposed account cache', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = SharedCache(prefs);
    final repo = MemoryShared();
    final c = SharedPlannerController(repo, cache, 'u', 'h');
    await tick();
    repo.pending = Completer<SharedView>();
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    c.dispose();
    await cache.clearUser('u');
    repo.pending!.complete(repo.current);
    await tick();
    expect(cache.read('u', 'h'), isNull);
  });
  test('uncertain edit stays reviewable and retry reuses request ID', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedCache(await SharedPreferences.getInstance());
    final repo = MemoryShared();
    final c = SharedPlannerController(repo, cache, 'u', 'h');
    await tick();
    repo.uncertain = true;
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    expect(c.pendingChanges, isNotNull);
    expect(c.canEdit, isFalse);
    repo.uncertain = false;
    await c.refresh();
    await c.retryPending();
    expect(repo.requests.length, 2);
    expect(repo.requests.first, repo.requests.last);
    expect(c.view!.snapshot.entries.first.cooked, isTrue);
    c.dispose();
  });
  test(
    'regeneration conflict remains visible after refreshing records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = SharedCache(await SharedPreferences.getInstance());
      final repo = MemoryShared();
      final c = SharedPlannerController(repo, cache, 'u', 'h');
      await tick();
      repo.regenConflict = true;
      c.generate(DateTime(2026, 10, 9), 1);
      await tick();
      expect(c.syncMessage, contains('Calendar changed'));
      c.dispose();
    },
  );

  test('fresh reconnect read completes before an edit can submit', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedCache(await SharedPreferences.getInstance());
    final repo = MemoryShared();
    final c = SharedPlannerController(repo, cache, 'u', 'h');
    await tick();
    repo.delayedFetch = Completer<SharedView>();
    final reload = c.refresh();
    c.setCooked(repo.current.snapshot.entries.first, true);
    await tick();
    expect(repo.sent, isNull);
    expect(c.canEdit, isFalse);
    repo.delayedFetch!.complete(repo.current);
    await reload;
    expect(c.canEdit, isTrue);
    c.dispose();
  });
}
