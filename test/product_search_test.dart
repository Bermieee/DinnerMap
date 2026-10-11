import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinnermap/features/region/region_models.dart';
import 'package:dinnermap/features/region/region_providers.dart';
import 'package:dinnermap/features/shopping/shopping_price_screen.dart';
import 'package:dinnermap/features/shopping/shopping_engine.dart';
import 'shopping_pricing_test.dart' show PriceRepository;
import 'package:dinnermap/features/shopping/product_search.dart';

class SearchRepository extends PriceRepository {
  String? lastQuery;
  @override
  Future<List<ProductOffer>> search(String id, String query) async {
    lastQuery = query;
    return [];
  }
}

void main() {
  testWidgets('Kroger receives cleaned search while recipe name stays intact', (
    t,
  ) async {
    final repo = SearchRepository();
    const name = 'boneless chicken breasts, cubed';
    await t.pumpWidget(
      ProviderScope(
        overrides: [regionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: GroceryProductPicker(
              repository: repo,
              storeId: '123',
              row: const ShoppingRow(
                key: 'chicken',
                name: name,
                quantity: 1,
                unit: 'lb',
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Price boneless chicken breasts'), findsOneWidget);
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    expect(repo.lastQuery, 'boneless chicken breasts');
    await t.enterText(
      find.widgetWithText(TextField, 'Search Kroger products'),
      'skinless chicken breast',
    );
    await t.tap(find.text('Search products'));
    await t.pumpAndSettle();
    expect(repo.lastQuery, 'skinless chicken breast');
    expect(t.takeException(), isNull);
  });
  test('store searches omit preparation and preserve product identity', () {
    const cases = {
      'boneless chicken breasts, cubed': 'boneless chicken breasts',
      'boneless skinless chicken breasts, cut into cubes':
          'boneless skinless chicken breasts',
      'onion, finely chopped': 'onion',
      'chopped green bell pepper': 'green bell pepper',
      'potatoes, peeled and cubed': 'potatoes',
      'ground beef, divided': 'ground beef',
      'frozen peas, thawed': 'frozen peas',
      'diced tomatoes, drained': 'diced tomatoes',
      'shredded cheddar cheese': 'shredded cheddar cheese',
      'sliced bread': 'sliced bread',
      'minced garlic': 'minced garlic',
      'cilantro, chopped (optional)': 'cilantro',
      'salt, to taste': 'salt',
      'cubed': 'cubed',
      'thin-sliced pork belly': 'pork belly',
      'butter, melted': 'butter',
      'egg, beaten': 'egg',
      'carrot (120 g)': 'carrot',
      'peeled and deveined shrimp': 'peeled and deveined shrimp',
      'diced green chiles': 'diced green chiles',
      'half and half': 'half and half',
      'macaroni and cheese': 'macaroni and cheese',
    };
    for (final entry in cases.entries) {
      expect(productSearchTerm(entry.key), entry.value, reason: entry.key);
    }
  });
}
