# DinnerMap Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a locally runnable Flutter Android/web meal planner and shopping list foundation without paid services.

**Architecture:** Structured domain models and pure shopping calculations feed a Riverpod controller and responsive Flutter screens. A local JSON repository persists demo plans. Cloud accounts and live retailer integrations are subsequent plans behind repository/adapter boundaries.

**Tech Stack:** Flutter stable, Dart, flutter_riverpod, shared_preferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-dinnermap-design.md`

## Global Constraints

- Android and web targets; visible local demo label.
- No paid billing configuration, API secrets, fake authentication or claims of working household sync.
- Preserve attributed prototype recipes and original quantities.
- Shopping ranges are 1, 2, 3 or 4 weeks from a selected start date.
- Every eventual household member can edit shared content.
- Retailer product sorting supports lowest and highest price.
- No live price or cart claims until authorized retailer integration is tested.

## Review Focus

- Unknown recipe servings: keep original quantities and warn instead of guessing scaling.
- Incompatible units or preparation: retain separate rows rather than silently combine.
- Date ranges crossing month/year: include dates in the interval exactly once.
- Corrupt local storage: preserve the saved payload for recovery and display an error.
- Calendar regeneration: retain manual shopping items and matching checkoffs.

## Scope boundary

This plan implements delivery sequence step 1 and the local portion of step 3. Authentication, invitations, realtime sync, security rules, online recipe browsing and live retailer services require their own implementation plans and provider setup. The Household screen explains that limitation rather than simulate sharing.

## File responsibilities

- `lib/main.dart`, `lib/app.dart`: app entry and responsive navigation.
- `lib/features/planner/models.dart`: serializable recipe, ingredient, plan and entry models.
- `lib/features/planner/planner_controller.dart`: immutable edits, undo and selected date/range.
- `lib/features/planner/planner_screen.dart`, `recipe_screen.dart`: calendar and recipe editing/detail UI.
- `lib/features/shopping/shopping_engine.dart`: scaling, aggregation, estimates and package calculations.
- `lib/features/shopping/shopping_models.dart`, `shopping_screen.dart`: saved list models and checklist UI.
- `lib/features/shopping/shopping_export.dart`: TXT/CSV content.
- `lib/data/planner_repository.dart`, `local_planner_repository.dart`: storage abstraction and local persistence.
- `lib/features/retailers/retailer_adapter.dart`: capability and offer contracts; no fabricated live implementation.
- `assets/recipes.json`: attributed recipes extracted from the HTML reference.
- `test/`: domain, persistence and widget regression tests.

### Task 1: Flutter project and recipe domain

**Interfaces:** `Ingredient(name, quantity, unit, preparation, originalText)`, `Recipe(id, title, baseServings, ingredients, instructions, sourceUrl)`, `PlanEntry(id, date, recipeId, targetServings, kind, cooked)`. Quantities and base servings may be null when unknown. `EntryKind` is recipe, takeout or leftovers.

- [ ] Create the Android/web project with `flutter create --platforms=android,web --org=com.dinnermap .`; retain documentation/reference files. Install Riverpod and shared_preferences and record the SDK version.
- [ ] Write model round-trip tests: nullable quantity and servings survive JSON; date-only serialization survives year boundaries; takeout has no recipe requirement.
- [ ] Run `flutter test test/models_test.dart`; confirm failure before implementing models.
- [ ] Implement immutable models and attributed extraction to `assets/recipes.json`; preserve unknown quantities and servings.
- [ ] Run model tests and asset-load validation; commit the passing domain foundation.

### Task 2: Grocery calculations

**Interfaces:** `ShoppingEngine.generate({required List<PlanEntry> entries, required Map<String, Recipe> recipes, required DateTime start, required int weeks}) -> ShoppingResult`. Result contains structured rows and warnings. `packagesRequired(double requiredAmount, double packageAmount) -> int` validates positive finite inputs.

- [ ] Write tests: 1 lb plus 8 oz compatible ingredient becomes 24 oz; bone-in and boneless remain separate; cups do not merge with grams; unknown servings warn without scaling; three-week Dec 20 range includes Jan 9 and excludes Jan 10; takeout/leftovers contribute no recipe ingredients; missing recipes warn; 5 lb / 2.5 lb requires 2 packages and 5.1 lb requires 3.
- [ ] Run `flutter test test/shopping_engine_test.dart`; confirm missing-engine failures.
- [ ] Implement conversions through grams/milliliters, explicit identity keys, range validation and warnings. Count estimates retain original counts and editable per-piece weight.
- [ ] Run shopping tests; commit the calculation engine.

### Task 3: Local saving and list regeneration

**Interfaces:** `PlannerRepository.load() -> Future<PlannerSnapshot?>`, `save(PlannerSnapshot snapshot) -> Future<void>`. `PlannerSnapshot` stores models, saved lists, manual items and schema version. `regenerateList(previous, result) -> SavedShoppingList` preserves stable matching checkoffs and manual entries.

- [ ] Write tests for save/load, schema rejection, corrupt-data recovery without overwrite, manual-item retention, checkoff preservation and stale source revision detection.
- [ ] Run `flutter test test/local_repository_test.dart test/list_regeneration_test.dart`; confirm failures.
- [ ] Implement shared_preferences JSON persistence and regeneration with stable ingredient identity. Expose persistence errors to the controller, leaving corrupt payload untouched until explicit reset/export.
- [ ] Run persistence/regeneration tests; commit local storage.

### Task 4: Responsive planner and recipes

**Interfaces:** Riverpod `PlannerController` exposes loaded state plus `replaceMeal`, `setEntryKind`, `setCooked`, `updateRecipe`, `randomizeRange`, `undo`, and date/range selection. Mutation methods persist through Task 3's repository.

- [ ] Write widget tests for recipe replacement, takeout exclusion after generation, undo, manual recipe edits and mobile/desktop layouts without overflow.
- [ ] Run targeted widget tests and confirm failures.
- [ ] Implement Calendar, Recipes, Shopping and Household navigation with dark Material styling. Include recipe detail, categories, favorites/avoidance and meal randomization. Display local-demo status and explain that account sync is pending.
- [ ] Run widget tests and `flutter analyze`; commit the UI.

### Task 5: Shopping UI, exports and retailer boundary

**Interfaces:** `shoppingText(SavedShoppingList) -> String`, `shoppingCsv(SavedShoppingList) -> String`; `RetailerAdapter` declares capabilities, store lookup, offer search and reviewed cart transfer. `RetailerOffer` has optional price, compatible package content, store and retrieval timestamp.

- [ ] Write tests for CSV commas/quotes/newlines, selected 1–4 week ranges, lb/oz toggles, editable count estimates and unknown prices sorted after numeric prices in both directions.
- [ ] Run targeted tests and confirm failures.
- [ ] Implement grouped shopping checkoffs, manual additions, stale-list regeneration and copy/export actions. Show a source-data warning when needed. Define retailer contracts and tested sorting/package logic; show integrations as unconnected, with no mock live prices or cart calls.
- [ ] Run all tests, `flutter analyze` and `flutter build web`. Run `flutter build apk --debug` if Android SDK is available; otherwise explicitly record the missing toolchain.
- [ ] Manually inspect mobile and desktop layouts; verify reload persistence, a two-week list and export. Update README with run commands, demonstrated capabilities and pending cloud/API work. Commit the verified foundation.

## Environment and delivery checks

Flutter is not currently on this workspace's PATH. Install the official stable SDK if network access permits; if blocked, record the exact failure and provide local setup commands rather than claim builds passed. Git clone worked, but push failed for missing GitHub authentication. Publish via the connected GitHub capability if available; otherwise keep local commits and report the delivery blocker.

## Self-review

All five review-focus cases map to tests above. Cloud requirements are explicitly deferred, not treated as completed by local storage. No paid service is required for this foundation. Model names and signatures are shared consistently between tasks.
