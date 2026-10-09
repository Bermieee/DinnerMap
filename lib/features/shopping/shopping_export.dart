import '../planner/models.dart';
import 'shopping_models.dart';
import 'shopping_engine.dart';

String shoppingText(
  SavedShoppingList list, {
  String massUnit = 'lb',
  Map<String, double> pieceWeights = const {},
}) => [
  'DinnerMap • ${dateKey(list.start)} • ${list.weeks} week(s)',
  ...list.rows.map(
    (r) =>
        '${list.checked.contains(r.key) ? '[x]' : '[ ]'} ${r.name}${r.preparation.isEmpty ? '' : ' (${r.preparation})'}: ${exportAmount(r, massUnit, pieceWeights)}',
  ),
  ...list.manualItems.map(
    (m) =>
        '${list.checked.contains(m.id) ? '[x]' : '[ ]'} ${m.name}: ${m.amount}',
  ),
  if (list.warnings.isNotEmpty) '\nReview before shopping:',
  ...list.warnings,
].join('\n');
String shoppingCsv(
  SavedShoppingList list, {
  String massUnit = 'lb',
  Map<String, double> pieceWeights = const {},
}) {
  String quote(String s) => '"${s.replaceAll('"', '""')}"';
  final rows = [
    ['Item', 'Amount', 'Checked', 'Notes'],
    ...list.rows.map(
      (r) => [
        r.name,
        exportAmount(r, massUnit, pieceWeights),
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
        m.amount,
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
