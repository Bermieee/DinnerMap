import '../lib/features/region/region_models.dart';
import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/shopping/shopping_pricing.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
  print('PASS $message');
}

void main() {
  const chicken = ShoppingRow(
    key: 'chicken|mass',
    name: 'chicken',
    unit: 'lb',
    quantity: 5,
  );
  const offer = ProductOffer(
    'p:1',
    'Chicken',
    price: 4.99,
    amount: 2,
    unit: 'lb',
    storeId: '123',
    soldBy: 'UNIT',
  );
  check(
    suggestPackages(chicken, offer) == 3,
    'five pounds requires three two-pound packages',
  );
  const oil = ShoppingRow(
    key: 'oil|volume',
    name: 'oil',
    unit: 'cup',
    quantity: 3,
  );
  check(
    suggestPackages(
          oil,
          const ProductOffer(
            'o',
            'Oil',
            amount: 16,
            unit: 'fl oz',
            soldBy: 'UNIT',
          ),
        ) ==
        2,
    'cups convert to fluid ounces before rounding up packages',
  );
  check(
    suggestPackages(
          chicken,
          const ProductOffer(
            'bad',
            'Milk',
            amount: 1,
            unit: 'gal',
            soldBy: 'UNIT',
          ),
        ) ==
        null,
    'incompatible units require manual package review',
  );
  const pieces = ShoppingRow(
    key: 'thighs|count',
    name: 'thighs',
    unit: 'count',
    quantity: 18,
  );
  check(
    suggestPackages(pieces, offer) == null,
    'piece count is not assumed to be weight',
  );
  check(
    suggestPackages(pieces, offer, pieceWeightOz: 6) == 4,
    'explicit piece-weight estimate supports package suggestion',
  );
  check(
    suggestPackages(
          chicken,
          const ProductOffer(
            'w',
            'Chicken',
            price: 2.49,
            amount: 1,
            unit: 'lb',
            soldBy: 'WEIGHT',
          ),
        ) ==
        null,
    'variable-weight offers are not counted as fixed packages',
  );
  check(
    suggestPackages(
          chicken,
          const ProductOffer(
            'u',
            'Chicken',
            price: 4.99,
            amount: 2,
            unit: 'lb',
          ),
        ) ==
        null,
    'unconfirmed sale basis never auto-suggests packages',
  );
  final selected = PriceSelection(row: chicken, offer: offer, packages: 3);
  check(selected.costCents == 1497, 'line estimate uses full package costs');
  check(
    selected.matches(chicken, '123') && !selected.matches(chicken, '456'),
    'store changes invalidate selected price',
  );
  check(
    !selected.matches(
      const ShoppingRow(
        key: 'chicken|mass',
        name: 'chicken',
        unit: 'lb',
        quantity: 6,
      ),
      '123',
    ),
    'changed grocery quantities invalidate selections',
  );
  check(
    quoteTotalCents([selected]) == 1497,
    'quote total uses selected line costs',
  );
  bool invalid = false;
  try {
    PriceSelection(row: chicken, offer: offer, packages: 0);
  } catch (_) {
    invalid = true;
  }
  check(invalid, 'invalid package count is rejected');
  for (final basis in ['UNKNOWN', 'WEIGHT']) {
    bool rejected = false;
    try {
      PriceSelection(
        row: chicken,
        offer: ProductOffer(
          'unsafe',
          'Chicken',
          price: 4.99,
          storeId: '123',
          soldBy: basis,
        ),
        packages: 1,
      );
    } catch (_) {
      rejected = true;
    }
    check(rejected, '$basis cannot silently become a package price');
  }
  check(quoteTotalCents([]) == null, 'unpriced list is not shown as free');
  check(
    const ProductOffer(
          'w',
          'Variable weight',
          price: 2.49,
          amount: 2,
          unit: 'lb',
          soldBy: 'WEIGHT',
        ).unitPrice ==
        null,
    'variable-weight price is not divided by package size',
  );
}
