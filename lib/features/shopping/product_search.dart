/// Suggest a store search without changing the recipe or grocery identity.
/// Preserve descriptors that identify common packaged product forms.
String productSearchTerm(String ingredient) {
  var term = ingredient.trim();
  final productForms = <String, String>{};
  final forms = RegExp(
    r'\b(diced tomatoes?|crushed tomatoes?|sliced bread|sliced cheese|shredded [\w -]*cheese|minced garlic|chopped nuts|chopped walnuts|chopped pecans|diced green chil(?:es|ies)|peeled(?: and)? deveined shrimp)\b',
    caseSensitive: false,
  );
  term = term.replaceAllMapped(forms, (match) {
    final key = 'productform${productForms.length}';
    productForms[key] = match.group(0)!;
    return key;
  });
  term = term.replaceAll(
    RegExp(r'\(\s*\d+(?:\.\d+)?\s*(?:g|kg|oz|lb)\s*\)', caseSensitive: false),
    ' ',
  );
  term = term.replaceAll(
    RegExp(
      r'\([^)]*(?:optional|to taste|for serving|for garnish)[^)]*\)',
      caseSensitive: false,
    ),
    ' ',
  );
  term = term.replaceAll(
    RegExp(
      r'\b(?:thin-sliced|cut into (?:cubes|pieces|strips)|(?:finely|roughly|coarsely|thinly|freshly)\s+(?:chopped|diced|sliced|minced|grated)|cubed|chopped|diced|sliced|minced|peeled|drained|rinsed|divided|trimmed|melted|beaten|halved|julienned|thawed|patted dry|to taste|for serving|for garnish|optional)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  term = term.replaceAll(RegExp(r'[,;()]'), ' ');
  term = term.replaceAll(RegExp(r'\s+'), ' ').trim();
  term = term.replaceAll(
    RegExp(r'^(?:and|then)\s+|\s+(?:and|then)$', caseSensitive: false),
    '',
  );
  for (final entry in productForms.entries) {
    term = term.replaceAll(entry.key, entry.value);
  }
  term = term.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Never turn an unfamiliar ingredient into an empty search.
  return term.isEmpty ? ingredient.trim() : term;
}
