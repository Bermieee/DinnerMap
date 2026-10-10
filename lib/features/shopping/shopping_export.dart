import '../planner/models.dart';
import 'shopping_models.dart';
import 'shopping_engine.dart';
import 'shopping_pricing.dart';
import 'consumer_amounts.dart';

String shoppingText(
  SavedShoppingList list, {
  String massUnit = 'lb',
  Map<String, double> pieceWeights = const {},
  Map<String, PriceSelection> selections = const {},
}) => [
  'DinnerMap • ${dateKey(list.start)} • ${list.weeks} week(s)',
  ...list.rows.map(
    (r) =>
        '${list.checked.contains(r.key) ? '[x]' : '[ ]'} ${r.name}${r.preparation.isEmpty ? '' : ' (${r.preparation})'}: ${purchaseExport(r, massUnit, pieceWeights, selections[r.key])}',
  ),
  ...list.manualItems.map(
    (m) =>
        '${list.checked.contains(m.id) ? '[x]' : '[ ]'} ${m.name}: ${selections['manual:${m.id}'] == null ? m.amount : buyPackages(selections['manual:${m.id}']!)}',
  ),
  if (list.warnings.isNotEmpty) '\nReview before shopping:',
  ...list.warnings,
].join('\n');
String shoppingCsv(
  SavedShoppingList list, {
  String massUnit = 'lb',
  Map<String, double> pieceWeights = const {},
  Map<String, PriceSelection> selections = const {},
}) {
  String quote(String s) => '"${s.replaceAll('"', '""')}"';
  final rows = [
    ['Item', 'Buy / Recipe amount', 'Checked', 'Notes'],
    ...list.rows.map(
      (r) => [
        r.name,
        purchaseExport(r, massUnit, pieceWeights, selections[r.key]),
        list.checked.contains(r.key) ? 'yes' : 'no',
        [
          r.preparation,
          if (r.quantity == null) 'Review quantity',
        ].where((s) => s.isNotEmpty).join('; '),
      ],
    ),
    ...list.manualItems.map(
      (m) => [
        m.name,
        selections['manual:${m.id}'] == null
            ? m.amount
            : buyPackages(selections['manual:${m.id}']!),
        list.checked.contains(m.id) ? 'yes' : 'no',
        'Manual item',
      ],
    ),
    ...list.warnings.map((w) => ['Warning', '', '', w]),
  ];
  return rows.map((r) => r.map(quote).join(',')).join('\r\n');
}

String exportAmount(
  ShoppingRow row,
  String unit,
  Map<String, double> pieceWeights,
) {
  final amount = rowAmount(row, unit);
  final perPiece = pieceWeights[row.key];
  final weight = perPiece == null ? null : row.estimatedOz(perPiece);
  if (weight == null) return amount;
  return '$amount; estimated ${(unit == 'lb' ? weight / 16 : weight).toStringAsFixed(2)} $unit ($perPiece oz per piece)';
}

String purchaseExport(
  ShoppingRow row,
  String massUnit,
  Map<String, double> pieceWeights,
  PriceSelection? selection,
) {
  final reviewed = selection != null && rowSignature(row) == selection.signature
      ? selection
      : null;
  return '${reviewed == null ? purchaseHint(row, massUnit: massUnit) : '${buyPackages(reviewed)} — ${reviewed.offer.name} (estimated \$${(reviewed.costCents / 100).toStringAsFixed(2)})'}; needed for recipes: ${exportAmount(row, massUnit, pieceWeights)}';
}
