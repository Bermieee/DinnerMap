import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/planner_repository.dart';
import '../planner/planner_controller.dart';
import '../shopping/shopping_engine.dart';
import 'shared_cache.dart';
import 'shared_models.dart';
import 'shared_repository.dart';

class _NoSnapshotRepository implements PlannerRepository {
  @override
  Future<PlannerSnapshot?> load() async => null;
  @override
  Future<String?> rawBackup() async => null;
  @override
  Future<void> save(PlannerSnapshot s) async =>
      throw StateError('Shared edits must use commands');
}

class SharedPlannerController extends PlannerController {
  final SharedRepository shared;
  final SharedCache cache;
  final String userId, householdId;
  SharedView? view;
  bool online = false, busy = false;
  String? status;
  List<Map<String, dynamic>>? conflictChanges;
  List<Map<String, dynamic>>? pendingChanges;
  String? _pendingRequestId;
  List<Map<String, dynamic>>? _inverse;
  StreamSubscription<bool>? _subscription;
  int _epoch = 0;
  bool _refreshing = false, _refreshAgain = false;
  SharedPlannerController(
    this.shared,
    this.cache,
    this.userId,
    this.householdId,
  ) : super(_NoSnapshotRepository(), autoLoad: false) {
    final cached = cache.read(userId, householdId);
    if (cached != null) {
      view = cached;
      state = AsyncValue.data(cached.snapshot);
    }
    _subscription = shared.watchConnection().listen(
      (connected) {
        online = connected;
        if (connected) {
          refresh();
        } else {
          status = 'Offline — shared plans are read-only.';
          _notify();
        }
      },
      onError: (Object e) {
        online = false;
        status = 'Connection lost — reload to reconnect.';
        _notify();
      },
    );
    refresh();
  }
  @override
  bool get canEdit =>
      online &&
      !busy &&
      view != null &&
      conflictChanges == null &&
      pendingChanges == null;
  @override
  String? get syncMessage => busy ? 'Saving shared changes…' : status;
  void _notify() {
    if (mounted && state.asData != null)
      state = AsyncValue.data(state.asData!.value);
  }

  Future<void> _accept(SharedView next, int epoch) async {
    if (!mounted || epoch != _epoch) return;
    view = next;
    state = AsyncValue.data(next.snapshot);
    // A disposed account must never repopulate its cache through a late write.
    await cache.write(userId, householdId, next);
    if (!mounted || epoch != _epoch)
      await cache.clearScope(userId, householdId);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    if (busy || _refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    final epoch = _epoch;
    try {
      final next = await shared.fetch();
      if (mounted && epoch == _epoch) {
        online = true;
        status = conflictChanges == null
            ? null
            : 'Another member changed this record. Review your edit.';
        await _accept(next, epoch);
      }
    } catch (e) {
      if (mounted && epoch == _epoch) {
        online = false;
        status = 'Could not reconnect. Cached shared plans are read-only.';
        if (view == null) state = AsyncValue.error(e, StackTrace.current);
      }
    } finally {
      _refreshing = false;
      _notify();
      if (_refreshAgain) {
        _refreshAgain = false;
        refresh();
      }
    }
  }

  List<Map<String, dynamic>> _undoCommands(
    SharedView before,
    List<Map<String, dynamic>> changes,
    SharedView after,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final c in changes) {
      final op = c['op'];
      final id = c['id'] as String;
      Object? old;
      String key;
      if (op == 'entry') {
        old = before.snapshot.entries
            .where((e) => e.id == id)
            .firstOrNull
            ?.toJson();
        key = 'entry:$id';
      } else if (op == 'recipe') {
        old = before.snapshot.recipes[id]?.toJson();
        key = 'recipe:$id';
      } else if (op == 'favorites') {
        old = before.snapshot.favorites.toList();
        key = 'preference:$id';
      } else if (op == 'avoided') {
        old = before.snapshot.avoided.toList();
        key = 'preference:$id';
      } else if (op == 'weights') {
        old = before.snapshot.pieceWeights;
        key = 'preference:$id';
      } else
        continue;
      if (old != null)
        result.add({
          'op': op,
          'id': id,
          'value': old,
          'expectedRevision': after.revisions[key],
        });
    }
    return result;
  }

  Future<void> _send(
    List<Map<String, dynamic>> changes, {
    bool remember = true,
    String? requestId,
  }) async {
    if (!canEdit || changes.isEmpty) return;
    final before = view!;
    busy = true;
    status = null;
    _notify();
    final epoch = _epoch;
    final id = requestId ?? const Uuid().v4();
    try {
      final next = await shared.apply(id, changes);
      if (mounted && epoch == _epoch) {
        if (remember) _inverse = _undoCommands(before, changes, next);
        await _accept(next, epoch);
        saveError = null;
      }
    } on SharedConflict catch (e) {
      if (mounted && epoch == _epoch) {
        conflictChanges = changes;
        status = e.message;
      }
    } catch (e) {
      if (mounted && epoch == _epoch) {
        online = false;
        pendingChanges = changes;
        _pendingRequestId = id;
        status = e.toString();
      }
    } finally {
      if (mounted && epoch == _epoch) {
        busy = false;
        _notify();
        if (conflictChanges != null || _refreshAgain) {
          _refreshAgain = false;
          await refresh();
        }
      }
    }
  }

  Future<void> retryPending() async {
    if (!online || busy || pendingChanges == null) return;
    final changes = pendingChanges!;
    final id = _pendingRequestId;
    pendingChanges = null;
    _pendingRequestId = null;
    await _send(changes, requestId: id);
  }

  void discardPending() {
    pendingChanges = null;
    _pendingRequestId = null;
    status = null;
    _notify();
  }

  @override
  void commitSnapshot(
    PlannerSnapshot snapshot, {
    bool mealChange = false,
    bool remember = true,
  }) {
    if (!canEdit) return;
    _send(changesBetween(view!, snapshot), remember: remember);
  }

  @override
  void undo() {
    final commands = _inverse;
    _inverse = null;
    if (commands != null) _send(commands, remember: false);
  }

  @override
  void generate(DateTime start, int weeks) {
    _generate(start, weeks);
  }

  Future<void> _generate(DateTime start, int weeks) async {
    if (!canEdit) return;
    busy = true;
    status = null;
    _notify();
    final epoch = _epoch;
    final before = view!;
    final result = ShoppingEngine.generate(
      entries: before.snapshot.entries,
      recipes: before.snapshot.recipes,
      start: start,
      weeks: weeks,
    );
    try {
      final next = await shared.regenerate(
        const Uuid().v4(),
        before.snapshot.revision,
        start,
        weeks,
        result.rows.map((r) => r.toJson()).toList(),
        result.warnings,
      );
      await _accept(next, epoch);
    } catch (e) {
      if (mounted && epoch == _epoch) {
        status = e.toString();
        if (e is! SharedConflict) online = false;
      }
    } finally {
      if (mounted && epoch == _epoch) {
        busy = false;
        _notify();
        await refresh();
      }
    }
  }

  String conflictPreview() => const JsonEncoder.withIndent('  ').convert({
    'current': view?.snapshot.toJsonForReview(),
    'proposed': conflictChanges,
  });
  Future<void> discardConflict() async {
    conflictChanges = null;
    status = null;
    await refresh();
  }

  Future<void> reapplyConflict() async {
    final changes = conflictChanges;
    if (changes == null || view == null) return;
    final next = changes.map((c) {
      final op = c['op'];
      final key = op == 'entry'
          ? 'entry:${c['id']}'
          : op == 'recipe'
          ? 'recipe:${c['id']}'
          : 'preference:${c['id']}';
      return {
        ...c,
        if (c.containsKey('expectedRevision'))
          'expectedRevision': view!.revisions[key] ?? -1,
      };
    }).toList();
    conflictChanges = null;
    await _send(next);
  }

  @override
  Future<void> importBackup(String raw) async {
    if (!canEdit) throw StateError('Reconnect before importing.');
    final snapshot = PlannerSnapshot.decode(raw);
    busy = true;
    _notify();
    final epoch = _epoch;
    try {
      await shared.importLocal(snapshot);
      final next = await shared.fetch();
      await _accept(next, epoch);
    } finally {
      if (mounted && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    ++_epoch;
    _subscription?.cancel();
    shared.dispose();
    super.dispose();
  }
}

extension on PlannerSnapshot {
  Object toJsonForReview() => jsonDecode(encode());
}
