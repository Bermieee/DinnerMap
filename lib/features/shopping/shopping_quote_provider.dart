import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../household/account_providers.dart';
import '../planner/planner_controller.dart';
import '../region/region_providers.dart';
import 'shopping_models.dart';
import 'shopping_pricing.dart';

class ShoppingQuote {
  final String? storeId;
  final Map<String, PriceSelection> selections;
  const ShoppingQuote({this.storeId, this.selections = const {}});
}

class QuoteSession extends StateNotifier<ShoppingQuote> {
  QuoteSession() : super(const ShoppingQuote());
  void selectStore(String? storeId) {
    if (state.storeId != storeId) state = ShoppingQuote(storeId: storeId);
  }

  void select(PriceSelection selection) {
    if (selection.offer.storeId != state.storeId) return;
    state = ShoppingQuote(
      storeId: state.storeId,
      selections: {...state.selections, selection.rowKey: selection},
    );
  }

  void remove(String key) => state = ShoppingQuote(
    storeId: state.storeId,
    selections: {...state.selections}..remove(key),
  );
  void clear() => state = ShoppingQuote(storeId: state.storeId);
  void reconcile(SavedShoppingList? list, {bool stale = false}) {
    if (list == null || stale) {
      if (state.selections.isNotEmpty) clear();
      return;
    }
    final rows = {for (final row in groceryRows(list)) row.key: row};
    final next = {...state.selections}
      ..removeWhere(
        (key, value) =>
            rows[key] == null ||
            !value.matches(rows[key]!, state.storeId ?? ''),
      );
    if (next.length != state.selections.length)
      state = ShoppingQuote(storeId: state.storeId, selections: next);
  }
}

// Session-only, scoped to the signed-in account and active planner. Survives
// closing the estimate screen so the grocery list and exports can use it.
final shoppingQuoteProvider =
    StateNotifierProvider<QuoteSession, ShoppingQuote>((ref) {
      ref.watch(regionalIdentityProvider);
      ref.watch(accountRepositoryProvider);
      ref.watch(plannerProvider.notifier);
      final session = QuoteSession();
      ref.listen(
        regionalStoreProvider,
        (previous, next) => session.selectStore(next),
      );
      ref.listen(plannerProvider, (previous, next) {
        final snapshot = next.asData?.value;
        session.reconcile(
          snapshot?.list,
          stale:
              snapshot?.list != null &&
              snapshot!.revision != snapshot.list!.sourceRevision,
        );
        final oldWeights = previous?.asData?.value.pieceWeights;
        if (oldWeights != null &&
            snapshot != null &&
            (oldWeights.length != snapshot.pieceWeights.length ||
                oldWeights.entries.any(
                  (e) => snapshot.pieceWeights[e.key] != e.value,
                )))
          session.clear();
      });
      return session;
    });
