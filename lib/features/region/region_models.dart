class RegionProfile {
  final String zip;
  final int radiusMiles;
  final String? selectedStoreId;
  RegionProfile(this.zip, {this.radiusMiles = 25, this.selectedStoreId}) {
    if (!RegExp(r'^\d{5}$').hasMatch(zip))
      throw ArgumentError('Enter a five-digit US ZIP code.');
    if (radiusMiles < 5 || radiusMiles > 100)
      throw ArgumentError('Choose a radius from 5 to 100 miles.');
  }
  Map<String, dynamic> toJson() => {
    'zip': zip,
    'radius_miles': radiusMiles,
    'selected_store_id': selectedStoreId,
  };
  factory RegionProfile.fromJson(Map<String, dynamic> json) => RegionProfile(
    json['zip'] as String,
    radiusMiles: json['radius_miles'] as int? ?? 25,
    selectedStoreId: json['selected_store_id'] as String?,
  );
}

class ZipRegion {
  final String zip, city, state;
  const ZipRegion(this.zip, this.city, this.state);
}

class StoreLocation {
  final String retailer, id, name, address, state;
  final String chain;
  const StoreLocation(
    this.retailer,
    this.id,
    this.name,
    this.address,
    this.state, {
    this.chain = '',
  });
  String get displayName {
    final brand = chain.trim(), location = name.trim();
    if (brand.isEmpty) return location.isEmpty ? 'Selected store' : location;
    final key = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final locationKey = location.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return location.isEmpty || locationKey.contains(key)
        ? (location.isEmpty ? brand : location)
        : '$brand • $location';
  }
}

enum OfferSort { packageLow, packageHigh, unitLow, unitHigh }

class ProductOffer {
  final String id, name;
  final double? price, amount;
  final String? unit;
  final String size, availability, storeId, soldBy;
  final DateTime? retrievedAt;
  const ProductOffer(
    this.id,
    this.name, {
    this.price,
    this.amount,
    this.unit,
    this.size = '',
    this.availability = 'Unknown',
    this.storeId = '',
    this.soldBy = 'UNKNOWN',
    this.retrievedAt,
  });
  bool get knownPrice => price != null && price!.isFinite && price! >= 0;
  double? get normalizedAmount {
    final n = amount;
    if (n == null || !n.isFinite || n <= 0) return null;
    return switch (unit?.toLowerCase()) {
      'lb' => n,
      'oz' => n / 16,
      'g' => n / 453.59237,
      'kg' => n * 1000 / 453.59237,
      'fl oz' => n,
      'gal' => n * 128,
      'qt' => n * 32,
      'pt' => n * 16,
      'ml' => n / 29.5735295625,
      'l' => n * 1000 / 29.5735295625,
      'count' => n,
      _ => null,
    };
  }

  double? get unitPrice =>
      soldBy == 'UNIT' && knownPrice && normalizedAmount != null
      ? price! / normalizedAmount!
      : null;
  String? get unitFamily => switch (unit?.toLowerCase()) {
    'lb' || 'oz' || 'g' || 'kg' => 'mass',
    'fl oz' || 'gal' || 'qt' || 'pt' || 'ml' || 'l' => 'volume',
    'count' => 'count',
    _ => null,
  };
  String? get unitLabel => switch (unitFamily) {
    'mass' => 'per lb',
    'volume' => 'per fl oz',
    'count' => 'each',
    _ => null,
  };
}

List<ProductOffer> sortProductOffers(
  List<ProductOffer> offers,
  OfferSort sort, {
  String? unitFamily,
}) {
  final result = [...offers];
  final byUnit = sort == OfferSort.unitLow || sort == OfferSort.unitHigh;
  final high = sort == OfferSort.packageHigh || sort == OfferSort.unitHigh;
  double? value(ProductOffer o) => byUnit
      ? (unitFamily != null && o.unitFamily == unitFamily ? o.unitPrice : null)
      : (o.knownPrice ? o.price : null);
  result.sort((a, b) {
    final av = value(a), bv = value(b);
    if (av == null || bv == null) {
      if (av != null) return -1;
      if (bv != null) return 1;
      return a.name.compareTo(b.name);
    }
    final compare = av.compareTo(bv);
    return compare == 0
        ? a.name.compareTo(b.name)
        : (high ? -compare : compare);
  });
  return result;
}
