class RetailerOffer {
  final String id, name;
  final double? price, packageAmount;
  final String? unit, storeId;
  final DateTime? retrievedAt;
  const RetailerOffer({
    required this.id,
    required this.name,
    this.price,
    this.packageAmount,
    this.unit,
    this.storeId,
    this.retrievedAt,
  });
}

List<RetailerOffer> sortOffers(List<RetailerOffer> offers, bool descending) {
  final result = [...offers];
  result.sort((a, b) {
    final ap = a.price, bp = b.price;
    final aKnown = ap != null && ap.isFinite && ap >= 0,
        bKnown = bp != null && bp.isFinite && bp >= 0;
    if (!aKnown) return bKnown ? 1 : a.name.compareTo(b.name);
    if (!bKnown) return -1;
    final c = ap.compareTo(bp);
    return descending ? -c : c;
  });
  return result;
}

class RetailerCapabilities {
  final bool storeLookup, productSearch, cartTransfer;
  const RetailerCapabilities({
    this.storeLookup = false,
    this.productSearch = false,
    this.cartTransfer = false,
  });
}

class RetailerStore {
  final String id, name;
  const RetailerStore(this.id, this.name);
}

class CartSelection {
  final String productId;
  final int packages;
  const CartSelection(this.productId, this.packages);
}

class CartTransferResult {
  final List<String> accepted, failed;
  final bool uncertain;
  const CartTransferResult({
    this.accepted = const [],
    this.failed = const [],
    this.uncertain = false,
  });
}

abstract class RetailerAdapter {
  RetailerCapabilities get capabilities;
  Future<List<RetailerStore>> stores(String zip);
  Future<List<RetailerOffer>> search(String query, String storeId);
  Future<CartTransferResult> transfer(List<CartSelection> reviewedSelections);
}
