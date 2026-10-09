import 'dart:convert';

import '../features/planner/models.dart';
import '../features/shopping/shopping_models.dart';

class PlannerSnapshot {
  final List<PlanEntry> entries;
  final Map<String, Recipe> recipes;
  final int revision;
  final SavedShoppingList? list;
  final Set<String> favorites, avoided;
  final Map<String, double> pieceWeights;
  const PlannerSnapshot({
    required this.entries,
    required this.recipes,
    this.revision = 0,
    this.list,
    this.favorites = const {},
    this.avoided = const {},
    this.pieceWeights = const {},
  });
  PlannerSnapshot copyWith({
    List<PlanEntry>? entries,
    Map<String, Recipe>? recipes,
    int? revision,
    SavedShoppingList? list,
    Set<String>? favorites,
    Set<String>? avoided,
    Map<String, double>? pieceWeights,
  }) => PlannerSnapshot(
    entries: entries ?? this.entries,
    recipes: recipes ?? this.recipes,
    revision: revision ?? this.revision,
    list: list ?? this.list,
    favorites: favorites ?? this.favorites,
    avoided: avoided ?? this.avoided,
    pieceWeights: pieceWeights ?? this.pieceWeights,
  );
  String encode() => jsonEncode({
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
    'recipes': recipes.values.map((r) => r.toJson()).toList(),
    'revision': revision,
    'list': list?.toJson(),
    'favorites': favorites.toList(),
    'avoided': avoided.toList(),
    'pieceWeights': pieceWeights,
  });
  factory PlannerSnapshot.decode(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['version'] != 1)
        throw const FormatException('Unsupported backup version');
      final recipes = (j['recipes'] as List).map(
        (r) => Recipe.fromJson(Map<String, dynamic>.from(r as Map)),
      );
      final result = PlannerSnapshot(
        entries: (j['entries'] as List)
            .map((e) => PlanEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recipes: {for (final r in recipes) r.id: r},
        revision: j['revision'] as int,
        list: j['list'] == null
            ? null
            : SavedShoppingList.fromJson(
                Map<String, dynamic>.from(j['list'] as Map),
              ),
        favorites: Set<String>.from(j['favorites'] as List? ?? []),
        avoided: Set<String>.from(j['avoided'] as List? ?? []),
        pieceWeights: Map<String, dynamic>.from(
          j['pieceWeights'] as Map? ?? {},
        ).map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
      if (result.revision < 0 ||
          result.entries.any(
            (e) => e.targetServings <= 0 || e.targetServings > 100,
          ))
        throw const FormatException('Invalid servings or revision');
      if (result.entries.map((e) => e.id).toSet().length !=
              result.entries.length ||
          result.entries.map((e) => dateKey(e.date)).toSet().length !=
              result.entries.length)
        throw const FormatException('Duplicate calendar entries');
      if (result.recipes.values.any(
        (r) =>
            r.id.isEmpty ||
            r.title.trim().isEmpty ||
            (r.baseServings != null &&
                (r.baseServings! <= 0 || r.baseServings! > 100)) ||
            r.ingredients.any(
              (i) =>
                  i.quantity != null &&
                  (!i.quantity!.isFinite || i.quantity! <= 0),
            ),
      ))
        throw const FormatException('Invalid recipe quantities');
      if (result.pieceWeights.values.any(
        (w) => !w.isFinite || w <= 0 || w > 48,
      ))
        throw const FormatException('Invalid piece weight');
      if (result.list?.rows.any(
            (r) =>
                r.quantity != null &&
                (!r.quantity!.isFinite || r.quantity! <= 0),
          ) ??
          false)
        throw const FormatException('Invalid grocery quantity');
      return result;
    } catch (e) {
      throw FormatException('Saved data could not be read: $e');
    }
  }
}

abstract class PlannerRepository {
  Future<PlannerSnapshot?> load();
  Future<void> save(PlannerSnapshot snapshot);
  Future<String?> rawBackup();
}
