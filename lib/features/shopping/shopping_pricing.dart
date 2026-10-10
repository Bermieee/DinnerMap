import 'dart:convert';
import '../region/region_models.dart';
import 'shopping_engine.dart';

int? suggestPackages(
  ShoppingRow row,
  ProductOffer offer, {
  double? pieceWeightOz,
}) {
  if (offer.soldBy != 'UNIT') return null;
  final amount = offer.normalizedAmount;
  final quantity = row.quantity;
  if (amount == null || quantity == null || !quantity.isFinite || quantity <= 0)
    return null;
  double? requiredAmount;
  if (family(row.unit) == 'mass' && offer.unitFamily == 'mass') {
    requiredAmount = row.amountIn('lb');
  } else if (family(row.unit) == 'volume' && offer.unitFamily == 'volume') {
    requiredAmount = row.amountIn('fl oz');
  } else if (row.unit == 'count' && offer.unitFamily == 'count') {
    requiredAmount = quantity;
  } else if (pieceWeightOz != null && offer.unitFamily == 'mass') {
    requiredAmount = row.estimatedOz(pieceWeightOz);
    if (requiredAmount != null) requiredAmount /= 16;
  }
  if (requiredAmount == null) return null;
  final packages = (requiredAmount / amount).ceil();
  return packages >= 1 && packages <= 999 ? packages : null;
}

String rowSignature(ShoppingRow row) => jsonEncode(row.toJson());

class PriceSelection {
  final String rowKey, signature;
  final ProductOffer offer;
  final int packages;
  PriceSelection({
    required ShoppingRow row,
    required this.offer,
    required this.packages,
    bool packageBasisConfirmed = false,
  }) : rowKey = row.key,
       signature = rowSignature(row) {
    if (packages < 1 ||
        packages > 999 ||
        !offer.knownPrice ||
        offer.storeId.isEmpty ||
        offer.soldBy == 'WEIGHT' ||
        (offer.soldBy != 'UNIT' && !packageBasisConfirmed)) {
      throw ArgumentError(
        'Select a priced fixed-package product and 1–999 packages.',
      );
    }
  }
  int get costCents => (offer.price! * 100).round() * packages;
  bool matches(ShoppingRow row, String storeId) =>
      offer.storeId == storeId && signature == rowSignature(row);
}

int? quoteTotalCents(Iterable<PriceSelection> selections) {
  if (selections.isEmpty) return null;
  return selections.fold<int>(
    0,
    (total, selection) => total + selection.costCents,
  );
}
