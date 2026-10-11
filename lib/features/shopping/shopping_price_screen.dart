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
            'Check ingredients, dietary needs and package sizes before accepting. Items needing review are excluded.',
          ),
          OutlinedButton(
            onPressed: automaticBusy || widget.stale ? null : acceptSuggestions,
            child: const Text('Accept reviewed suggestions'),
          ),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == null || widget.stale
                      ? 'Estimated list total: —'
                      : 'Estimated list total: \$${(total / 100).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${valid.length} of ${rows.length} items priced'),
                const Text(
                  'Unpriced items are excluded. Taxes, fees, coupons and final variable weights are not included. Prices may change.',
                ),
              ],
            ),
          ),
        ),
        for (final row in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.key.startsWith('manual:')
                        ? row.name
                        : productSearchTerm(row.name),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Needed for recipes: ${rowAmount(row, 'lb')}'),
                  if (searchNotes[row.key] case final note?) Text(note),
                  if (suggestions[row.key] case final suggestion?) ...[
                    Text('Suggested: ${suggestion.offer.name}'),
                    Text(
                      '${buyPackages(suggestion)} • \$${(suggestion.costCents / 100).toStringAsFixed(2)}',
                    ),
                    Text(
                      '\$${suggestion.offer.unitPrice?.toStringAsFixed(2) ?? '—'} ${suggestion.offer.unitLabel ?? ''}',
                    ),
                    TextButton(
                      onPressed: automaticBusy || widget.stale
                          ? null
                          : () {
                              if (suggestion.matches(
                                    row,
                                    profile?.selectedStoreId ?? '',
                                  ) &&
                                  ref.read(shoppingQuoteProvider).storeId ==
                                      profile?.selectedStoreId) {
                                quotes.select(suggestion);
                                setState(() => suggestions.remove(row.key));
                              }
                            },
                      child: const Text('Use this suggestion'),
                    ),
                  ],
                  if (selectionFor(row) case final selected?) ...[
                    Text(
                      buyPackages(selected),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(selected.offer.name),
                    Text(
                      '${selected.packages} package(s) × \$${selected.offer.price!.toStringAsFixed(2)} = \$${(selected.costCents / 100).toStringAsFixed(2)}',
                    ),
                    Text(selected.offer.size),
                    if (selected.offer.retrievedAt != null)
                      Text(
                        'Price retrieved ${selected.offer.retrievedAt!.toLocal()}',
                      ),
                    TextButton(
                      onPressed: () => quotes.remove(row.key),
                      child: const Text('Remove product'),
                    ),
                  ] else
                    Text(purchaseHint(row)),
                  OutlinedButton(
                    onPressed:
                        !loading &&
                            !automaticBusy &&
                            store != null &&
                            !widget.stale
                        ? () => selectProduct(row)
                        : null,
                    child: Text(
                      selectionFor(row) == null
                          ? 'Find Kroger product'
                          : 'Change product',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (rows.isEmpty) const Text('No groceries to price.'),
      ],
    );
  }
}

class GroceryProductPicker extends ConsumerStatefulWidget {
  final RegionRepository repository;
  final String storeId;
  final ShoppingRow row;
  final double? pieceWeightOz;
  const GroceryProductPicker({
    super.key,
    required this.repository,
    required this.storeId,
    required this.row,
    this.pieceWeightOz,
  });
  @override
  ConsumerState<GroceryProductPicker> createState() =>
      _GroceryProductPickerState();
}

class _GroceryProductPickerState extends ConsumerState<GroceryProductPicker> {
  late final query = TextEditingController(
    text: productSearchTerm(widget.row.name),
  );
  final packages = TextEditingController();
  List<ProductOffer> offers = [];
  ProductOffer? selected;
  bool busy = false, confirmed = false, searched = false;
  String? error;
  int generation = 0;
  @override
  void dispose() {
    generation++;
    query.dispose();
    packages.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final term = query.text.trim();
    if (term.length < 2 || term.length > 100) {
      setState(() => error = 'Search must contain 2–100 characters.');
      return;
    }
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      offers = [];
      selected = null;
      confirmed = false;
      packages.clear();
    });
    try {
      final results = await widget.repository.search(widget.storeId, term);
      if (results.any((offer) => offer.storeId != widget.storeId))
        throw StateError('Results did not match the selected store.');
      if (mounted && request == generation)
        setState(() {
          offers = sortProductOffers(results, OfferSort.packageLow);
          searched = true;
          busy = false;
        });
    } catch (e) {
      if (mounted && request == generation)
        setState(() {
          error = '$e';
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountChanged = !identical(
      ref.watch(regionRepositoryProvider),
      widget.repository,
    );
    final count = int.tryParse(packages.text);
    return AdaptiveAlertDialog(
      title: Text(
        'Price ${widget.row.key.startsWith('manual:') ? widget.row.name : productSearchTerm(widget.row.name)}',
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Needed: ${rowAmount(widget.row, 'lb')} • Kroger store ${widget.storeId}',
            ),
            if (accountChanged)
              const Text('Account changed. Close this search and try again.'),
            TextField(
              controller: query,
              onChanged: (_) => setState(() {
                generation++;
                searched = false;
                busy = false;
                offers = [];
                selected = null;
                error = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Search Kroger products',
              ),
              onSubmitted: (_) {
                if (!accountChanged && !busy) search();
              },
            ),
            TextButton(
              onPressed: busy || accountChanged ? null : search,
              child: const Text('Search products'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!busy && offers.isNotEmpty && !accountChanged)
              SizedBox(
                height: 230,
                child: ListView(
                  children: [
                    for (final offer in offers)
                      ListTile(
                        title: Text(offer.name),
                        subtitle: Text(
                          '${offer.size.isEmpty ? 'Size unknown' : offer.size} • ${offer.knownPrice ? '\$${offer.price!.toStringAsFixed(2)}' : 'Price unavailable'}\n${offer.soldBy == 'WEIGHT'
                              ? 'Variable weight: package quote unavailable'
                              : offer.soldBy == 'UNIT'
                              ? 'Fixed package'
                              : 'Confirm package basis before pricing'} • ${offer.availability}',
                        ),
                        selected: identical(offer, selected),
                        onTap: !offer.knownPrice || offer.soldBy == 'WEIGHT'
                            ? null
                            : () => setState(() {
                                selected = offer;
                                confirmed = offer.soldBy == 'UNIT';
                                packages.text =
                                    suggestPackages(
                                      widget.row,
                                      offer,
                                      pieceWeightOz: widget.pieceWeightOz,
                                    )?.toString() ??
                                    '';
                              }),
                      ),
                  ],
                ),
              ),
            if (!busy && error == null && offers.isEmpty)
              Text(
                searched
                    ? 'No matching products found. Try another search.'
                    : 'Search for a product, then review its size and price.',
              ),
            if (selected != null && !accountChanged) ...[
              if (estimatedPurchaseGrams(widget.row) != null &&
                  selected!.unitFamily == 'mass')
                Text(
                  'Estimated shopping weight: ${readableAmount(estimatedPurchaseGrams(widget.row)!, 'g')}. Uses an ingredient-specific cup-to-weight estimate; review the package.',
                ),
              Text('Selected: ${selected!.name}'),
              if (suggestPackages(
                    widget.row,
                    selected!,
                    pieceWeightOz: widget.pieceWeightOz,
                  ) ==
                  null)
                const Text(
                  'Package count cannot be calculated reliably. Enter the number of fixed packages you want.',
                ),
              if (widget.pieceWeightOz != null)
                const Text(
                  'Any weight-based suggestion uses your estimated ounces per piece.',
                ),
              TextField(
                controller: packages,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Packages to buy (1–999)',
                ),
              ),
              if (selected!.soldBy != 'UNIT')
                CheckboxListTile(
                  value: confirmed,
                  onChanged: (v) => setState(() => confirmed = v ?? false),
                  title: const Text(
                    'I confirm this price is for one fixed package',
                  ),
                ),
              if (count != null && count >= 1 && count <= 999)
                Text(
                  'Line estimate: \$${((selected!.price! * 100).round() * count / 100).toStringAsFixed(2)}',
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              selected != null &&
                  confirmed &&
                  !accountChanged &&
                  !busy &&
                  count != null &&
                  count >= 1 &&
                  count <= 999
              ? () => Navigator.pop(
                  context,
                  PriceSelection(
                    row: widget.row,
                    offer: selected!,
                    packages: count,
                    packageBasisConfirmed: confirmed,
                  ),
                )
              : null,
          child: const Text('Use product estimate'),
        ),
      ],
    );
  }
}
