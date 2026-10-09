int? parseBaseServings(String note) {
  final match = RegExp(
    r'^Serves\s+(\d+)(?:\s*;|\s*$)',
    caseSensitive: false,
  ).firstMatch(note.trim());
  return match == null ? null : int.tryParse(match[1]!);
}

DateTime parseDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      dateKey(parsed) != value ||
      parsed.year < 2020 ||
      parsed.year > 2100)
    throw const FormatException('Invalid calendar date');
  return parsed;
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

enum EntryKind { recipe, takeout, leftovers }

class Ingredient {
  final String name, unit, preparation, originalText;
  final double? quantity;
  const Ingredient({
    required this.name,
    this.quantity,
    this.unit = 'count',
    this.preparation = '',
    this.originalText = '',
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'preparation': preparation,
    'originalText': originalText,
  };
  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
    name: j['name'] as String,
    quantity: (j['quantity'] as num?)?.toDouble(),
    unit: j['unit'] as String? ?? 'count',
    preparation: j['preparation'] as String? ?? '',
    originalText: j['originalText'] as String? ?? '',
  );
}

class Recipe {
  final String id, title, instructions, sourceUrl, category, region;
  final int? baseServings;
  final List<Ingredient> ingredients;
  final bool incomplete;
  const Recipe({
    required this.id,
    required this.title,
    this.baseServings,
    this.ingredients = const [],
    this.instructions = '',
    this.sourceUrl = '',
    this.category = 'quick',
    this.region = '',
    this.incomplete = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'baseServings': baseServings,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'instructions': instructions,
    'sourceUrl': sourceUrl,
    'category': category,
    'region': region,
    'incomplete': incomplete,
  };
  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] as String,
    title: j['title'] as String,
    baseServings: j['baseServings'] as int?,
    ingredients: (j['ingredients'] as List)
        .map((i) => Ingredient.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList(),
    instructions: j['instructions'] as String? ?? '',
    sourceUrl: j['sourceUrl'] as String? ?? '',
    category: j['category'] as String? ?? 'quick',
    region: j['region'] as String? ?? '',
    incomplete: j['incomplete'] == true,
  );
}

class PlanEntry {
  final String id, notes;
  final DateTime date;
  final String? recipeId;
  final int targetServings;
  final EntryKind kind;
  final bool cooked;
  const PlanEntry({
    required this.id,
    required this.date,
    this.recipeId,
    this.targetServings = 4,
    this.kind = EntryKind.recipe,
    this.cooked = false,
    this.notes = '',
  });
  PlanEntry copyWith({
    String? recipeId,
    int? targetServings,
    EntryKind? kind,
    bool? cooked,
    String? notes,
  }) => PlanEntry(
    id: id,
    date: date,
    recipeId: recipeId ?? this.recipeId,
    targetServings: targetServings ?? this.targetServings,
    kind: kind ?? this.kind,
    cooked: cooked ?? this.cooked,
    notes: notes ?? this.notes,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dateKey(date),
    'recipeId': recipeId,
    'targetServings': targetServings,
    'kind': kind.name,
    'cooked': cooked,
    'notes': notes,
  };
  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
    id: j['id'] as String,
    date: parseDate(j['date'] as String),
    recipeId: j['recipeId'] as String?,
    targetServings: j['targetServings'] as int? ?? 4,
    kind: EntryKind.values.byName(j['kind'] as String),
    cooked: j['cooked'] == true,
    notes: j['notes'] as String? ?? '',
  );
}
