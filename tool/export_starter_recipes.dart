import 'dart:convert';
import 'dart:io';
import '../lib/features/planner/starter_recipes.dart';
export '../lib/features/planner/starter_recipes.dart' show loadRecipes;

void main() {
  final raw =
      jsonDecode(File('assets/recipes.json').readAsStringSync()) as List;
  stdout.write(jsonEncode(loadRecipes(raw).map((r) => r.toJson()).toList()));
}
