import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../layout/adaptive_page.dart';
import '../planner/planner_controller.dart';
import '../region/region_models.dart';
import '../region/region_providers.dart';
import '../region/region_repository.dart';
import '../region/region_screen.dart';
import 'shopping_engine.dart';
import 'shopping_models.dart';
import 'shopping_pricing.dart';
import 'shopping_quote_provider.dart';
import 'consumer_amounts.dart';
import 'product_search.dart';
import 'automatic_pricing.dart';

class ShoppingPriceScreen extends ConsumerWidget {
  const ShoppingPriceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(regionRepositoryProvider);
    final snapshot = ref.watch(plannerProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Kroger list estimate')),
      body: snapshot?.list == null
          ? const Center(child: Text('Generate a shopping list first.'))
          : AdaptivePage(
              child: ShoppingPricePanel(
                key: ValueKey((
                  repository,
                  ref.watch(plannerProvider.notifier),
                )),
                repository: repository,
                list: snapshot!.list!,
                pieceWeights: snapshot.pieceWeights,
                stale: snapshot.revision != snapshot.list!.sourceRevision,
              ),
            ),
    );
  }
}

class ShoppingPricePanel extends ConsumerStatefulWidget {
  final RegionRepository repository;
  final SavedShoppingList list;
  final Map<String, double> pieceWeights;
  final bool stale;
  const ShoppingPricePanel({
    super.key,
    required this.repository,
    required this.list,
    this.pieceWeights = const {},
    this.stale = false,
  });
  @override
  ConsumerState<ShoppingPricePanel> createState() => _ShoppingPricePanelState();
}

class _ShoppingPricePanelState extends ConsumerState<ShoppingPricePanel> {
  RegionProfile? profile;
  Map<String, PriceSelection> get selections =>
      ref.read(shoppingQuoteProvider).selections;
  QuoteSession get quotes => ref.read(shoppingQuoteProvider.notifier);
  bool loading = true;
  bool automaticBusy = false;
  int automaticGeneration = 0, completedSearches = 0, searchCount = 0;
  final Map<String, PriceSelection> suggestions = {};
  final Map<String, String> searchNotes = {};

  void cancelAutomatic() {
    automaticGeneration++;
    automaticBusy = false;
  }

  bool contextMatches(int request, String store, RegionRepository repository) =>
      mounted &&
      request == automaticGeneration &&
      !widget.stale &&
      identical(repository, ref.read(regionRepositoryProvider)) &&
      ref.read(shoppingQuoteProvider).storeId == store &&
      profile?.selectedStoreId == store;

  Future<void> findBestDeals() async {
    final store = profile?.selectedStoreId;
    if (store == null || widget.stale || automaticBusy) return;
    final repository = widget.repository;
    final pending = rows.where((row) => selectionFor(row) == null).toList();
    final request = ++automaticGeneration;
    setState(() {
      suggestions.clear();
      searchNotes.clear();
      automaticBusy = true;
      completedSearches = 0;
      searchCount = pending.length;
    });
    for (final row in pending) {
      if (!contextMatches(request, store, repository)) break;
      try {
        final offers = await repository.search(
          store,
          productSearchTerm(row.name),
        );
        if (!contextMatches(request, store, repository)) break;
        final best = bestDeal(
          row,
          offers,
          store,
          pieceWeightOz: widget.pieceWeights[row.key],
        );
        setState(() {
          if (best == null) {
            searchNotes[row.key] =
                'Needs review: no suitable priced package with a known quantity.';
          } else {
            suggestions[row.key] = best;
          }
          completedSearches++;
        });
      } catch (e) {
        if (!contextMatches(request, store, repository)) break;
        setState(() {
          searchNotes[row.key] =
              'Search failed. Use Find Kroger product to retry.';
          completedSearches++;
        });
      }
      // Pace searches below the existing 30-request/minute account quota.
      if (completedSearches < searchCount) {
        await Future<void>.delayed(const Duration(milliseconds: 2200));
      }
    }
    if (mounted && request == automaticGeneration) {
      setState(() => automaticBusy = false);
    }
  }

  void acceptSuggestions() {
    if (automaticBusy || widget.stale) return;
    final store = profile?.selectedStoreId;
    if (store != ref.read(shoppingQuoteProvider).storeId) return;
    for (final row in rows) {
      final suggestion = suggestions[row.key];
      if (suggestion != null &&
          suggestion.matches(row, store ?? '') &&
          selectionFor(row) == null)
        quotes.select(suggestion);
    }
    setState(() => suggestions.clear());
  }

  @override
  void dispose() {
    automaticGeneration++;
    super.dispose();
  }

  String? error;
  int generation = 0, pickerGeneration = 0;
  @override
  void didUpdateWidget(covariant ShoppingPricePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.list, widget.list) ||
        oldWidget.stale != widget.stale ||
        oldWidget.pieceWeights.length != widget.pieceWeights.length ||
        oldWidget.pieceWeights.entries.any(
          (e) => widget.pieceWeights[e.key] != e.value,
        )) {
      pickerGeneration++;
      cancelAutomatic();
      suggestions.clear();
      searchNotes.clear();
      final list = widget.list, stale = widget.stale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) quotes.reconcile(list, stale: stale);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final request = ++generation;
    pickerGeneration++;
    cancelAutomatic();
    suggestions.clear();
    searchNotes.clear();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.repository.load();
      if (!mounted || request != generation) return;
      setState(() {
        quotes.selectStore(next?.selectedStoreId);
        profile = next;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation)
        setState(() {
          loading = false;
          error = '$e';
        });
    }
  }

  List<ShoppingRow> get rows => groceryRows(widget.list);
  PriceSelection? selectionFor(ShoppingRow row) {
    final selection = selections[row.key];
    return selection != null &&
            selection.matches(row, profile?.selectedStoreId ?? '')
        ? selection
        : null;
  }

  Future<void> selectProduct(ShoppingRow row) async {
    final store = profile?.selectedStoreId;
    if (store == null || widget.stale) return;
    final request = pickerGeneration;
    final result = await showDinnerMapDialog<PriceSelection>(
      context: context,
      builder: (_) => GroceryProductPicker(
        repository: widget.repository,
        storeId: store,
        row: row,
        pieceWeightOz: widget.pieceWeights[row.key],
      ),
    );
    if (!mounted ||
        request != pickerGeneration ||
        result == null ||
        widget.stale)
      return;
    if (rows.any(
      (current) => result.matches(current, profile?.selectedStoreId ?? ''),
    )) {
      quotes.select(result);
      setState(() {
        suggestions.remove(row.key);
        searchNotes.remove(row.key);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(shoppingQuoteProvider);
    ref.listen(shoppingQuoteProvider, (previous, next) {
      if (previous?.storeId != next.storeId) {
        setState(() {
          cancelAutomatic();
          suggestions.clear();
          searchNotes.clear();
        });
      }
    });
    final valid = rows.map(selectionFor).whereType<PriceSelection>().toList();
    final total = quoteTotalCents(valid);
    final store = profile?.selectedStoreId;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Review products for your grocery list',
          style: TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a product; we calculate whole packages where sizes are compatible. Reviewed choices also appear on your grocery list and exports during this app session.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegionScreen(),
                    ),
                  );
                  if (mounted) await loadProfile();
                },
          icon: const Icon(Icons.store),
          label: Text(
            store == null ? 'Select a Kroger store' : 'Change Kroger store',
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: loadProfile, child: const Text('Retry')),
        ],
        if (!loading && store == null)
          const Text(
            'Save your ZIP and select a store in Stores & prices. Live prices require the Kroger connection to be configured.',
          ),
        if (store != null) Text('Prices at Kroger store $store'),
        if (widget.stale)
          const Text(
            'Your meal plan changed. Regenerate the shopping list before selecting prices.',
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: loading || automaticBusy || store == null || widget.stale
              ? null
              : findBestDeals,
          icon: const Icon(Icons.manage_search),
          label: const Text('Find best deals at Kroger'),
        ),
        const Text(
          'Finds the lowest cost for enough whole packages among suitable returned products. Suggestions require review. Existing reviewed choices are kept.',
        ),
        if (automaticBusy) ...[
          LinearProgressIndicator(
            value: searchCount == 0 ? null : completedSearches / searchCount,
          ),
          Text('Searching $completedSearches of $searchCount items…'),
          TextButton(
            onPressed: () => setState(cancelAutomatic),
            child: const Text('Stop search'),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          Text(
            '${suggestions.length} suggestions • estimated subtotal: \$${(quoteTotalCents(suggestions.values)! / 100).toStringAsFixed(2)}',
          ),
          const Text(
            'Check ingredients, dietary needs and package sizes before …10837 tokens truncated…> retryPending() async {
    if (!online || busy || _refreshing || pendingChanges == null) return;
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
  void updateEntry(PlanEntry entry, {PlanEntry? expectedEntry}) {
    final current = view?.snapshot.entries
        .where((e) => e.id == entry.id)
        .firstOrNull;
    if (expectedEntry != null &&
        current != null &&
        jsonEncode(current.toJson()) != jsonEncode(expectedEntry.toJson())) {
      conflictChanges = [
        {
          'op': 'entry',
          'id': entry.id,
          'value': entry.toJson(),
          'expectedRevision': view!.revisions['entry:${entry.id}'] ?? -1,
        },
      ];
      status =
          'This meal changed while you were editing. Review both versions.';
      _notify();
      return;
    }
    super.updateEntry(entry, expectedEntry: expectedEntry);
  }

  @override
  void updateRecipe(Recipe recipe, {Recipe? expectedRecipe}) {
    if (!canEdit) return;
    final current = view?.snapshot.recipes[recipe.id];
    if (expectedRecipe != null &&
        current != null &&
        jsonEncode(current.toJson()) != jsonEncode(expectedRecipe.toJson())) {
      conflictChanges = [
        {
          'op': 'recipe',
          'id': recipe.id,
          'value': recipe.toJson(),
          'expectedRevision': view!.revisions['recipe:${recipe.id}'] ?? -1,
        },
      ];
      status =
          'This recipe changed while you were editing. Review both versions.';
      _notify();
      return;
    }
    super.updateRecipe(recipe, expectedRecipe: expectedRecipe);
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
    final before = view!;
    final result = ShoppingEngine.generate(
      entries: before.snapshot.entries,
      recipes: before.snapshot.recipes,
      start: start,
      weeks: weeks,
    );
    await _sendGeneration(
      PendingGeneration(
        const Uuid().v4(),
        before.snapshot.revision,
        start,
        weeks,
        result.rows.map((r) => r.toJson()).toList(),
        result.warnings,
      ),
    );
  }

  Future<void> _sendGeneration(PendingGeneration proposal) async {
    if (!online || busy || _refreshing) return;
    busy = true;
    status = null;
    generationMessage = null;
    _notify();
    final epoch = _epoch;
    try {
      final next = await shared.regenerate(
        proposal.requestId,
        proposal.revision,
        proposal.start,
        proposal.weeks,
        proposal.rows,
        proposal.warnings,
      );
      await _accept(next, epoch);
      if (mounted && epoch == _epoch) {
        pendingGeneration = null;
        generationMessage = null;
      }
    } catch (e) {
      if (mounted && epoch == _epoch) {
        pendingGeneration = proposal;
        proposal.recompute = e is SharedConflict;
        generationMessage = e is SharedConflict
            ? '${e.toString()}. Reloaded the calendar; retry groceries to use its latest meals.'
            : 'Grocery generation has an uncertain result. Reload, then retry groceries safely.';
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

  Future<void> retryGeneration() async {
    final proposal = pendingGeneration;
    if (proposal == null || !online || busy || _refreshing) return;
    if (proposal.recompute) {
      pendingGeneration = null;
      generationMessage = null;
      await _generate(proposal.start, proposal.weeks);
    } else {
      // Reusing the original payload/request makes an accepted-but-lost reply safe.
      await _sendGeneration(proposal);
    }
  }

  void discardGeneration() {
    pendingGeneration = null;
    generationMessage = null;
    status = null;
    _notify();
  }

  String conflictPreview() {
    final snapshot = view?.snapshot;
    final records = (conflictChanges ?? pendingChanges ?? []).map((c) {
      final id = c['id'];
      final op = c['op'];
      Object? current;
      if (op == 'entry')
        current = snapshot?.entries
            .where((e) => e.id == id)
            .firstOrNull
            ?.toJson();
      if (op == 'recipe') current = snapshot?.recipes[id]?.toJson();
      if (op == 'favorites') current = snapshot?.favorites.toList();
      if (op == 'avoided') current = snapshot?.avoided.toList();
      if (op == 'clearList') current = snapshot?.list?.toJson();
      if (op == 'weights') current = snapshot?.pieceWeights;
      return {'record': id, 'current': current, 'proposed': c['value']};
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(records);
  }

  Future<void> discardConflict() async {
    conflictChanges = null;
    status = null;
    await refresh();
  }

  bool get canReapplyConflict =>
      mounted &&
      online &&
      !busy &&
      !_refreshing &&
      view != null &&
      conflictChanges != null &&
      !conflictChanges!.any((c) => c['op'] == 'clearList') &&
      pendingChanges == null &&
      pendingGeneration == null;

  Future<void> reapplyConflict() async {
    if (!canReapplyConflict) return;
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
    if (!mounted || !canEdit) throw StateError('Reconnect before importing.');
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
