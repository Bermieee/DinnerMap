import 'dart:convert';
import '../../data/planner_repository.dart';

class SharedView {
  final PlannerSnapshot snapshot;
  final Map<String, int> revisions;
  const SharedView(this.snapshot, this.revisions);
  factory SharedView.fromJson(Map<String, dynamic> j) => SharedView(
    PlannerSnapshot.decode(jsonEncode(j['snapshot'])),
    Map<String, dynamic>.from(
      j['recordRevisions'] as Map,
    ).map((k, v) => MapEntry(k, (v as num).toInt())),
  );
  String encode() => jsonEncode({
    'snapshot': jsonDecode(snapshot.encode()),
    'recordRevisions': revisions,
  });
  factory SharedView.decode(String raw) =>
      SharedView.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class SharedConflict implements Exception {
  final String message;
  const SharedConflict(this.message);
  @override
  String toString() => message;
}

class SharedUnavailable implements Exception {
  final String message;
  final bool uncertain;
  const SharedUnavailable(this.message, {this.uncertain = false});
  @override
  String toString() => message;
}

List<Map<String, dynamic>> changesBetween(
  SharedView before,
  PlannerSnapshot next,
) {
  final old = before.snapshot;
  final result = <Map<String, dynamic>>[];
  void add(String op, String id, Object? value, String revisionKey) {
    result.add({
      'op': op,
      'id': id,
      'value': value,
      'expectedRevision': before.revisions[revisionKey] ?? -1,
    });
  }

  for (final r in next.recipes.values) {
    if (jsonEncode(old.recipes[r.id]?.toJson()) != jsonEncode(r.toJson()))
      add('recipe', r.id, r.toJson(), 'recipe:${r.id}');
  }
  for (final e in next.entries) {
    final previous = old.entries.where((p) => p.id == e.id).firstOrNull;
    if (jsonEncode(previous?.toJson()) != jsonEncode(e.toJson()))
      add('entry', e.id, e.toJson(), 'entry:${e.id}');
  }
  if (!old.favorites.containsAll(next.favorites) ||
      !next.favorites.containsAll(old.favorites))
    add(
      'favorites',
      'favorites',
      next.favorites.toList(),
      'preference:favorites',
    );
  if (!old.avoided.containsAll(next.avoided) ||
      !next.avoided.containsAll(old.avoided))
    add('avoided', 'avoided', next.avoided.toList(), 'preference:avoided');
  if (jsonEncode(old.pieceWeights) != jsonEncode(next.pieceWeights))
    add(
      'weights',
      'pieceWeights',
      next.pieceWeights,
      'preference:pieceWeights',
    );
  final list = next.list;
  final previous = old.list;
  if (list != null && previous != null) {
    for (final m in list.manualItems) {
      if (!previous.manualItems.any((p) => p.id == m.id))
        result.add({'op': 'manual', 'id': m.id, 'value': m.toJson()});
    }
    for (final m in previous.manualItems) {
      if (!list.manualItems.any((p) => p.id == m.id))
        result.add({'op': 'removeManual', 'id': m.id});
    }
    final remainingKeys = {
      ...list.rows.map((r) => r.key),
      ...list.manualItems.map((m) => m.id),
    };
    for (final key in {...previous.checked, ...list.checked}) {
      if (!remainingKeys.contains(key)) continue;
      if (previous.checked.contains(key) != list.checked.contains(key))
        result.add({
          'op': 'check',
          'id': key,
          'value': list.checked.contains(key),
        });
    }
  }
  return result;
}
