import '../lib/features/shopping/automatic_pricing.dart';
import '../lib/features/shopping/shopping_engine.dart';
import '../lib/features/region/region_models.dart';

void main() {
  const row = ShoppingRow(
    key: 'chicken',
    name: 'boneless skinless chicken breasts, cubed',
    quantity: 3,
    unit: 'lb',
  );
  const offers = [
    ProductOffer(
      'large',
      'Boneless Skinless Chicken Breasts',
      price: 12,
      amount: 5,
      unit: 'lb',
      storeId: '123',
      soldBy: 'UNIT',
    ),
    ProductOffer(
      'small',
      'Boneless Skinless Chicken Breast',
      price: 5,
      amount: 2,
      unit: 'lb',
      storeId: '123',
      soldBy: 'UNIT',
    ),
    ProductOffer(
      'wrong',
      'Boneless Skinless Chicken Breast Broth',
      price: 1,
      amount: 5,
      unit: 'lb',
      storeId: '123',
      soldBy: 'UNIT',
    ),
  ];
  final best = bestDeal(row, offers, '123');
  if (best?.offer.id != 'small' ||
      best?.packages != 2 ||
      best?.costCents != 1000)
    throw StateError('Use lowest sufficient total, not unit price');
  if (bestDeal(row, [offers[2]], '123') != null)
    throw StateError('Reject wrong ingredient');
  if (bestDeal(row, [offers[0]], 'different') != null)
    throw StateError('Reject other store');
  const loose = ProductOffer(
    'loose',
    'Boneless Skinless Chicken Breast',
    price: 1,
    amount: 2,
    unit: 'lb',
    storeId: '123',
    soldBy: 'WEIGHT',
  );
  if (bestDeal(row, [loose], '123') != null)
    throw StateError('Reject variable weight');
  const unknown = ShoppingRow(
    key: 'x',
    name: 'onion',
    unit: 'text',
    quantity: null,
  );
  if (bestDeal(unknown, [offers[0]], '123') != null)
    throw StateError('Do not guess quantities');
  const milk = ShoppingRow(key: 'm', name: 'milk', quantity: 1, unit: 'l');
  const almond = ProductOffer(
    'almond',
    'Almond Milk',
    price: 2,
    amount: 1,
    unit: 'l',
    storeId: '123',
    soldBy: 'UNIT',
  );
  if (bestDeal(milk, [almond], '123') != null)
    throw StateError('Do not silently substitute plant milk');
  const butter = ShoppingRow(
    key: 'b',
    name: 'butter',
    quantity: 1,
    unit: 'cup',
  );
  const peanut = ProductOffer(
    'p',
    'Peanut Butter',
    price: 1,
    amount: 1,
    unit: 'lb',
    storeId: '123',
    soldBy: 'UNIT',
  );
  if (bestDeal(butter, [peanut], '123') != null)
    throw StateError('Reject peanut butter for cooking butter');
  if (suitableProduct('butter', 'Apple Butter') ||
      suitableProduct('chicken', 'Chicken Salad') ||
      suitableProduct('butter', 'Butter Cookies') ||
      suitableProduct('chicken', 'Chicken Dog Treats') ||
      suitableProduct('milk', 'Chocolate Milk') ||
      suitableProduct('flour', 'Flour Tortillas'))
    throw StateError('Reject different foods sharing ingredient words');
  if (!suitableProduct('peanut butter', 'Creamy Peanut Butter') ||
      !suitableProduct('butter', 'Kroger Salted Sweet Cream Butter'))
    throw StateError('Keep legitimate product forms');
  print('PASS 9 automatic deal checks');
}
