import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/planner_repository.dart';
import 'models.dart';
import '../shopping/shopping_engine.dart';
import '../shopping/shopping_models.dart';

final repositoryProvider = Provider<PlannerRepository>(
  (ref) => throw StateError('Repository not configured'),
);
final plannerProvider =
    StateNotifierProvider<PlannerController, AsyncValue<PlannerSnapshot>>(
      (ref) => PlannerController(ref.read(repositoryProvider)),
    );

class PlannerController extends StateNotifier<AsyncValue<PlannerSnapshot>> {
  final PlannerRepository repository;
  PlannerSnapshot? _undo;
  String? saveError;
  bool _blocked = false;
  bool _restoring = false;
  Future<void> _queue = Future.value();
  PlannerController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }
  Future<void> load() async {
    try {
      final saved = await repository.load();
      if (saved != null) {
        state = AsyncValue.data(saved);
        return;
      }
      final raw = jsonDecode(
        await rootBundle.loadString('assets/recipes.json'),
      ) as List;
      final recipes = raw.map((value) {
        final j = Map<String, dynamic>.from(value as Map);
        final yield = j['yieldNote'] as String? ?? '';
        final servings = RegExp(r'[Ss]erves\s+(\d+)').firstMatch(yield);
        return Recipe(
          id: j['id'] as String,
          title: j['name'] as String,
          baseServings: servings == null ? null : int.parse(servings[1]!),
          category: j['type'] as String? ?? 'quick',
          region: j['area'] as String? ?? '',
          sourceUrl: j['original'] as String? ?? '',
          incomplete: j['incomplete'] == true,
          instructions:
              'Open the source recipe for cooking directions. ${yield.isEmpty ? 'Original source quantities; confirm servings before scaling.' : yield}',
          ingredients: (j['ingredients'] as List).map((value) {
            final i = Map<String, dynamic>.from(value as Map);
            final measure = i['measure'] as String;
            final parsed = parseMeasure(measure);
            return Ingredient(
              name: i['name'] as String,
              quantity: parsed.quantity,
              unit: parsed.unit,
              originalText: measure,
            );
          }).toList(),
        );
      }).toList();
      final today = dateOnly(DateTime.now());
      state = AsyncValue.data(
        PlannerSnapshot(
          recipes: {for (final r in recipes) r.id: r},
          entries: [
            for (var i = 0; i < 28; i++)
              PlanEntry(
                id: 'day-$i',
                date: DateTime(today.year, today.month, today.day + i),
                recipeId: recipes[i % recipes.length].id,
              ),
          ],
        ),
      );
    } catch (e, st) {
      _blocked = true;
      state = AsyncValue.error(e, st);
    }
  }

  void _set(
    PlannerSnapshot snapshot, {
    bool mealChange = false,
    bool remember = true,
  }) {
    if (_blocked || _restoring) return;
    final current = state.asData?.value;
    if (current == null) return;
    if (remember) _undo = current;
    final next = snapshot.copyWith(
      revision: mealChange ? current.revision + 1 : current.revision,
    );
    state = AsyncValue.data(next);
    _queue = _queue.then((_) async {
      try {
        await repository.save(next);
        saveError = null;
      } catch (e) {
        saveError = e.toString();
        if (mounted) state = AsyncValue.data(state.asData!.value);
      }
    });
  }

  void updateEntry(PlanEntry entry) {
    final s = state.asData!.value;
    _set(
      s.copyWith(
        entries: s.entries.any((e) => e.id == entry.id)
            ? s.entries.map((e) => e.id == entry.id ? entry : e).toList()
            : [...s.entries, entry],
      ),
      mealChange: true,
    );
  }

  void replaceMeal(PlanEntry entry, Recipe recipe) => updateEntry(
    entry.copyWith(recipeId: recipe.id, kind: EntryKind.recipe, cooked: false),
  );
  void setEntryKind(PlanEntry entry, EntryKind kind) =>
      updateEntry(entry.copyWith(kind: kind));
  void setCooked(PlanEntry entry, bool value) =>
      updateEntry(entry.copyWith(cooked: value));
  void updateRecipe(Recipe recipe) {
    final s = state.asData!.value;
    _set(
      s.copyWith(recipes: {...s.recipes, recipe.id: recipe}),
      mealChange: true,
    );
  }

  void favorite(String id) {
    final s = state.asData!.value;
    final ids = {...s.favorites};
    if (!ids.add(id)) ids.remove(id);
    _set(s.copyWith(favorites: ids));
  }

  void avoid(String id) {
    final s = state.asData!.value;
    final ids = {...s.avoided};
    if (!ids.add(id)) ids.remove(id);
    _set(s.copyWith(avoided: ids));
  }

  void randomizeRange(DateTime start, int days) {
    final s = state.asData!.value;
    final available = s.recipes.values
        .where((r) => !s.avoided.contains(r.id))
        .toList();
    if (available.isEmpty) return;
    final end = DateTime(start.year, start.month, start.day + days);
    final random = Random();
    _set(
      s.copyWith(
        entries: s.entries
            .map(
              (e) =>
                  e.kind == EntryKind.recipe &&
                      !e.date.isBefore(start) &&
                      e.date.isBefore(end)
                  ? e.copyWith(
                      recipeId: available[random.nextInt(available.length)].id,
                      cooked: false,
                    )
                  : e,
            )
            .toList(),
      ),
      mealChange: true,
    );
  }

  void undo() {
    final previous = _undo;
    if (previous != null) {
      _undo = null;
      _set(previous, mealChange: true, remember: false);
    }
  }

  void generate(DateTime start, int weeks) {
    final s = state.asData!.value;
    final result = ShoppingEngine.generate(
      entries: s.entries,
      recipes: s.recipes,
      start: start,
      weeks: weeks,
    );
    final previous =
        s.list ??
        SavedShoppingList(
          start: start,
          weeks: weeks,
          sourceRevision: s.revision,
        );
    _set(
      s.copyWith(
        list: regenerateList(
          previous,
          result,
          s.revision,
          start: start,
          weeks: weeks,
        ),
      ),
    );
  }

  void checkItem(String key, bool checked) {
    final s = state.asData!.value;
    final list = s.list;
    if (list == null) return;
    final ids = {...list.checked};
    checked ? ids.add(key) : ids.remove(key);
    _set(s.copyWith(list: list.copyWith(checked: ids)));
  }

  void addManual(String name, String amount) {
    final s = state.asData!.value;
    final list = s.list;
    if (list == null) return;
    _set(
      s.copyWith(
        list: list.copyWith(
          manualItems: [
            ...list.manualItems,
            ManualItem(
              id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              amount: amount,
            ),
          ],
        ),
      ),
    );
  }

  void removeManual(String id) {
    final s = state.asData!.value;
    final l = s.list!;
    _set(
      s.copyWith(
        list: l.copyWith(
          manualItems: l.manualItems.where((m) => m.id != id).toList(),
          checked: {...l.checked}..remove(id),
        ),
      ),
    );
  }

  void setPieceWeight(String key, double weight) {
    if (!weight.isFinite || weight <= 0 || weight > 48) return;
    final s = state.asData!.value;
    _set(s.copyWith(pieceWeights: {...s.pieceWeights, key: weight}));
  }

  Future<void> importBackup(String raw) async {
    final restored = PlannerSnapshot.decode(raw);
    _restoring = true;
    final operation = _queue.then((_) async {
      await repository.save(restored);
      _blocked = false;
      _undo = null;
      saveError = null;
      if (mounted) state = AsyncValue.data(restored);
    });
    _queue = operation.catchError((Object _) {});
    try {
      await operation;
    } finally {
      _restoring = false;
    }
  }
}
