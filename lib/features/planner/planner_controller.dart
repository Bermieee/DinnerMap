import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/planner_repository.dart';
import 'models.dart';
import 'month_plan.dart';
import 'starter_recipes.dart';
import '../shopping/shopping_engine.dart';
import '../shopping/shopping_models.dart';

final repositoryProvider = Provider<PlannerRepository>(
  (ref) => throw StateError('Repository not configured'),
);
final plannerFactoryProvider = Provider<PlannerController Function()?>(
  (ref) => null,
);
final plannerProvider =
    StateNotifierProvider<PlannerController, AsyncValue<PlannerSnapshot>>(
      (ref) =>
          ref.watch(plannerFactoryProvider)?.call() ??
          PlannerController(ref.read(repositoryProvider)),
    );

class PlannerController extends StateNotifier<AsyncValue<PlannerSnapshot>> {
  final PlannerRepository repository;
  PlannerSnapshot? undoSnapshot;
  bool get canEdit => true;
  String? get syncMessage => null;
  String? saveError;
  bool _blocked = false;
  bool _restoring = false;
  Future<void> _queue = Future.value();
  PlannerController(this.repository, {bool autoLoad = true})
    : super(const AsyncValue.loading()) {
    if (autoLoad) load();
  }
  Future<void> load() async {
    try {
      final saved = await repository.load();
      if (saved != null) state = AsyncValue.data(saved);
      final recipes = loadRecipes(
        jsonDecode(await rootBundle.loadString('assets/recipes.json')) as List,
      );
      if (saved != null) {
        if (!mounted || _restoring) return;
        final current = state.asData?.value ?? saved;
        final upgraded = addDiscoveryStarters(current, recipes);
        if (!identical(current, upgraded)) {
          commitSnapshot(upgraded, mealChange: true, remember: false);
          await _queue;
        }
        return;
      }
      final dates = monthDates(DateTime.now());
      state = AsyncValue.data(
        PlannerSnapshot(
          recipes: {for (final r in recipes) r.id: r},
          entries: [
            for (var i = 0; i < dates.length; i++)
              PlanEntry(
                id: 'day-${dateKey(dates[i])}',
                date: dates[i],
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

  void commitSnapshot(
    PlannerSnapshot snapshot, {
    bool mealChange = false,
    bool remember = true,
  }) {
    if (_blocked || _restoring) return;
    final current = state.asData?.value;
    if (current == null) return;
    if (remember) undoSnapshot = current;
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

  void updateEntry(PlanEntry entry, {PlanEntry? expectedEntry}) {
    final s = state.asData!.value;
    commitSnapshot(
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
    expectedEntry: entry,
  );
  void setEntryKind(PlanEntry entry, EntryKind kind) =>
      updateEntry(entry.copyWith(kind: kind), expectedEntry: entry);
  void setCooked(PlanEntry entry, bool value) =>
      updateEntry(entry.copyWith(cooked: value), expectedEntry: entry);
  void updateRecipe(Recipe recipe, {Recipe? expectedRecipe}) {
    final s = state.asData!.value;
    commitSnapshot(
      s.copyWith(recipes: {...s.recipes, recipe.id: recipe}),
      mealChange: true,
    );
  }

  void favorite(String id) {
    final s = state.asData!.value;
    final ids = {...s.favorites};
    if (!ids.add(id)) ids.remove(id);
    commitSnapshot(s.copyWith(favorites: ids));
  }

  void avoid(String id) {
    final s = state.asData!.value;
    final ids = {...s.avoided};
    if (!ids.add(id)) ids.remove(id);
    commitSnapshot(s.copyWith(avoided: ids));
  }

  void randomizeRange(DateTime start, int days) {
    final s = state.asData!.value;
    final available = s.recipes.values
        .where((r) => !s.avoided.contains(r.id))
        .toList();
    if (available.isEmpty) return;
    final end = DateTime(start.year, start.month, start.day + days);
    final random = Random();
    commitSnapshot(
      s.copyWith(
        entries:
            fillPlanRange(
                  s.entries,
                  start,
                  days,
                  () => available[random.nextInt(available.length)].id,
                )
                .map(
                  (e) =>
                      e.kind == EntryKind.recipe &&
                          !e.date.isBefore(start) &&
                          e.date.isBefore(end)
                      ? e.copyWith(
                          recipeId:
                              available[random.nextInt(available.length)].id,
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
    final previous = undoSnapshot;
    if (previous != null) {
      undoSnapshot = null;
      commitSnapshot(previous, mealChange: true, remember: false);
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
    commitSnapshot(
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
    commitSnapshot(s.copyWith(list: list.copyWith(checked: ids)));
  }

  void addManual(String name, String amount) {
    final s = state.asData!.value;
    final list = s.list;
    if (list == null) return;
    commitSnapshot(
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
    commitSnapshot(
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
    commitSnapshot(s.copyWith(pieceWeights: {...s.pieceWeights, key: weight}));
  }

  Future<void> importBackup(String raw) async {
    final restored = PlannerSnapshot.decode(raw);
    _restoring = true;
    final operation = _queue.then((_) async {
      await repository.save(restored);
      _blocked = false;
      undoSnapshot = null;
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
