import '../planner/models.dart';
import 'shopping_engine.dart';

class ManualItem {
  final String id, name, amount;
  const ManualItem({required this.id, required this.name, this.amount = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount};
  factory ManualItem.fromJson(Map<String, dynamic> j) => ManualItem(
    id: j['id'] as String,
    name: j['name'] as String,
    amount: j['amount'] as String? ?? '',
  );
}

class SavedShoppingList {
  final DateTime start;
  final int weeks, sourceRevision;
  final List<ShoppingRow> rows;
  final Set<String> checked;
  final List<ManualItem> manualItems;
  final List<String> warnings;
  const SavedShoppingList({
    required this.start,
    required this.weeks,
    required this.sourceRevision,
    this.rows = const [],
    this.checked = const {},
    this.manualItems = const [],
    this.warnings = const [],
  });
  SavedShoppingList copyWith({
    Set<String>? checked,
    List<ManualItem>? manualItems,
  }) => SavedShoppingList(
    start: start,
    weeks: weeks,
    sourceRevision: sourceRevision,
    rows: rows,
    checked: checked ?? this.checked,
    manualItems: manualItems ?? this.manualItems,
    warnings: warnings,
  );
  Map<String, dynamic> toJson() => {
    'start': dateKey(start),
    'weeks': weeks,
    'sourceRevision': sourceRevision,
    'rows': rows.map((r) => r.toJson()).toList(),
    'checked': checked.toList(),
    'manualItems': manualItems.map((m) => m.toJson()).toList(),
    'warnings': warnings,
  };
  factory SavedShoppingList.fromJson(Map<String, dynamic> j) {
    final weeks = j['weeks'] as int;
    if (weeks < 1 || weeks > 4)
      throw const FormatException('Shopping range must be 1–4 weeks');
    return SavedShoppingList(
      start: parseDate(j['start'] as String),
      weeks: j['weeks'] as int,
      sourceRevision: j['sourceRevision'] as int,
      rows: (j['rows'] as List)
          .map((r) => ShoppingRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      checked: Set<String>.from(j['checked'] as List),
      manualItems: (j['manualItems'] as List)
          .map((m) => ManualItem.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      warnings: List<String>.from(j['warnings'] as List? ?? []),
    );
  }
}

SavedShoppingList regenerateList(
  SavedShoppingList previous,
  ShoppingResult result,
  int revision, {
  DateTime? start,
  int? weeks,
}) {
  final keys = {
    ...result.rows.map((r) => r.key),
    ...previous.manualItems.map((m) => m.id),
  };
  return SavedShoppingList(
    start: start ?? previous.start,
    weeks: weeks ?? previous.weeks,
    sourceRevision: revision,
    rows: result.rows,
    checked: previous.checked.intersection(keys),
    manualItems: previous.manualItems,
    warnings: result.warnings,
  );
}

String rowAmount(ShoppingRow row, String massUnit) {
  if (row.quantity == null) return row.sourceText.toSet().join(' + ');
  final q = family(row.unit) == 'mass' ? row.amountIn(massUnit) : row.quantity!;
  final unit = family(row.unit) == 'mass' ? massUnit : row.unit;
  return '${q.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} $unit';
}

String groceryGroup(String name) {
  final s = name.toLowerCase();
  if (RegExp('frozen').hasMatch(s)) return 'Frozen';
  if (RegExp(
        'chicken|beef|pork|steak|shrimp|salmon|turkey|bacon|sausage',
      ).hasMatch(s) &&
      !RegExp('stock|broth|sauce').hasMatch(s))
    return 'Meat & seafood';
  if (RegExp('milk|cheese|butter|egg|cream|yogurt').hasMatch(s))
    return 'Dairy & eggs';
  if (RegExp(
        'onion|carrot|potato|garlic|tomato|lettuce|lemon|lime|broccoli|cabbage|zucchini|celery',
      ).hasMatch(s) &&
      !RegExp('powder|sauce|paste').hasMatch(s))
    return 'Produce';
  if (RegExp('bread|rice|flour|pasta|tortilla|noodle|bun').hasMatch(s))
    return 'Bakery & grains';
  return 'Pantry & other';
}
