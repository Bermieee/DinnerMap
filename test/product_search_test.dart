import 'package:flutter_test/flutter_test.dart';
import '../lib/features/shopping/product_search.dart';

void main() {
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
    };
    for (final entry in cases.entries) {
      expect(productSearchTerm(entry.key), entry.value, reason: entry.key);
    }
  });
}
