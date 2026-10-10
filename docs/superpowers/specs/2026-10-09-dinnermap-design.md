# DinnerMap design

## Purpose and agreed scope

DinnerMap is a household meal planner and grocery list app for Android and web, built with Flutter. It starts with the behavior in `reference/monthly-meal-planner-v13.html`. A future public release should use the same household boundaries without a redesign.

Users sign in with separate accounts and share saved calendars and grocery lists through a household. Every household member can edit shared content. Grocery product results support price ascending and descending sorting. Retailer access is implemented through official Kroger and Walmart APIs when credentials and permissions are available.

## Recommended foundation

Use Flutter with Riverpod for presentation state and repositories for data access. Firebase Authentication, Cloud Firestore and TypeScript Cloud Functions are candidate services, not committed dependencies. Build the local foundation first. Before deploying accounts or retailer services, compare providers' current quotas, required billing accounts and expected household/public costs with the user. Do not enable paid billing during foundation development. Keep persistence and retailer access behind interfaces so the provider decision does not require rewriting the planner.

Local-only storage is simpler but does not satisfy cross-device sharing. A custom database and authentication backend offers more control but adds maintenance before the household version is useful. Firebase provides the shortest path to accounts and shared data.

## First implementation milestone

Build a working Android/web planner with authentication, household creation/joining, shared calendars, recipes and saved shopping lists. Include Firebase setup instructions and an explicitly labeled local demo mode so the UI and calculations can be exercised without cloud credentials. Demo data is separate from authenticated household data; demo edits do not silently upload.

Retailer interfaces and product selection UI belong in the foundation. Live Kroger and Walmart connections follow as separate milestones. Mock products must be visibly labeled and must never be represented as live inventory or prices.

## Planner behavior

Provide Calendar, Recipes, Shopping and Household screens with responsive layouts. Preserve the prototype's dark visual style, meal categories, recipe details, favorites, avoided recipes, meal replacement, randomization, cooked markers, takeout days and backup/export behavior.

The initial plan supports 28 days, with dated calendars capable of representing actual calendar months. Shopping ranges select a starting date and 1, 2, 3 or 4 weeks. Calendar entries can have a recipe, takeout or leftovers designation. Takeout requires no recipe ingredients. Leftovers are excluded unless explicitly assigned additional ingredients.

Recipes store structured ingredients, instructions, source attribution, base servings and optional images. Each scheduled recipe has a servings target. Imported prototype recipes with unknown base servings require user confirmation before scaling; the app must not invent serving counts. Manual recipes remain available without a recipe service.

Recipe browsing can later use TheMealDB through an adapter after checking production terms. Bundled prototype content must retain attribution and be reviewed for redistribution before public release. A missing recipe source must show an incomplete-shopping warning rather than imply the list is complete.

## Shopping calculations

Aggregate ingredients across the selected date range and scale known recipe quantities by target/base servings. Merge only ingredients with compatible identity, preparation requirements and units. Keep bone-in and boneless chicken separate. Mass converts through grams; volume converts through milliliters; counts remain counts. Do not convert volume to mass without an ingredient-specific density.

Display pounds or ounces for mass. Count-to-weight conversions, such as chicken thighs, are visibly labeled estimates with editable per-piece weight. Preserve original counts alongside estimated weights. Unparsed quantities stay visible as text and require review; they never disappear from totals.

Saved shopping lists record date range, source calendar revision, ingredient quantities and user additions. Regeneration updates recipe-derived quantities while preserving manual items and matching checkoffs. Show when calendar changes make a saved list stale and let users regenerate. Checking an item leaves it visible. Users can copy, share, print through the browser, and export TXT/CSV; Android uses platform sharing for exports.

## Accounts and household sharing

An account may belong to one household initially. Any member can invite another signed-in account through an expiring, single-use invitation redeemed by the backend. Invitations grant membership only to the specified household. Joining is explicit; changing households must not move existing data silently.

Every member can edit plans, recipes and lists, and invite members. A user may leave the household; removing other members or deleting a household is outside the first milestone. Account deletion removes personal access and retailer connections without deleting other members' shared content.

All shared records carry household ID, creator/updater IDs, server timestamps and revision fields. Use document-level records for calendar entries and shopping items so unrelated edits do not overwrite an entire plan. Transactions detect conflicting edits to the same meal or recipe and offer reload/reapply instead of silently replacing newer changes. Shopping checkoffs use last accepted update semantics.

Offline editing is supported where Firestore provides persistence. Display pending sync and failures. Android and web persistence configuration must be explicit; persistent web caching should be opt-in on shared computers.

## Data boundaries

- `users/{uid}`: profile and current household reference, writable only by that user with validated fields.
- `households/{householdId}`: shared display name and configuration.
- Household subcollections `members`, `calendars`, `calendarEntries`, `recipes`, `shoppingLists`, `shoppingItems`: shared domain records with verified membership access.
- Backend-only invitation and retailer token records: inaccessible to client reads and writes.

Security rules enforce membership, allowed fields and quantity limits. Clients cannot grant themselves membership or change household ownership references to bypass authorization. The backend creates and redeems invitations atomically. Test cross-household isolation with Firebase emulators.

## Retailer matching and cart flow

Define a retailer adapter with capabilities for store lookup, product search, local offers and cart transfer. Capabilities vary by granted API access; unsupported actions are disabled with a clear explanation.

The user selects a store and searches suggested products for each ingredient. Results show package size, package price, unit price where calculable, availability and retrieval time. Sort lowest/highest package price; offer unit-price sorting separately. Exclude unknown prices from numeric ordering and show them after priced results.

Calculate packages as the ceiling of required amount divided by compatible package content. Variable-weight products use estimated totals and clearly disclose that final amounts may change. Ambiguous sizes require manual quantity selection. The user reviews mappings and quantities before explicitly requesting cart transfer. Retail checkout happens with the retailer; DinnerMap does not place orders.

Kroger is the first live integration. Public API scopes and supported cart operations must be verified against the registered application before implementation. Walmart OPD documentation describes local offers and shoppable carts, but access is subject to its partnership process. Keep Walmart available as a planned adapter, with list export/search links as a fallback until authorized access exists.

Store API secrets in backend secret storage, never Flutter assets. Customer OAuth connections are personal to each account. Use state validation and PKCE where supported, encrypted server-side token storage, expiry handling and revocation on disconnect. Never share retailer credentials with household members.

## Errors and recovery

Keep saved plans usable when recipe sources or retailers fail. Surface authentication expiry, unavailable products, missing quantities and partial cart results. A cart timeout must not trigger an automatic retry that could duplicate quantities. Report uncertain results and ask the user to inspect the retailer cart. Cache offers for responsiveness but disclose freshness and revalidate before transfer where supported.

## Validation and completion criteria

Test unit compatibility, fractional parsing, serving scaling, aggregation, takeout exclusions, count estimates and package rounding. Test grocery regeneration preservation and stale-list detection. Use widget tests for range selection, sorting and product review. Use Firebase emulator tests for household isolation, invitations and concurrent edits.

Verify Android and web builds, Flutter analysis and meaningful automated tests. Manually verify a two-account household flow: create/join household, edit a calendar from both clients, generate a two-week list, check items across devices and export the list. Live retailer milestones require real authorized credentials and a reported end-to-end test; local mocks cannot establish API integration success.

## Delivery sequence

1. Flutter foundation and migration of planner calculations/reference data.
2. Firebase accounts, household membership and shared persistence.
3. Shopping generation, exports and cross-device validation.
4. Kroger product matching and reviewed cart transfer.
5. Walmart integration after approved access, then public-release preparation.

Public-release preparation includes data deletion/export, privacy documentation, service terms, abuse controls, API quotas, billing limits and recipe redistribution review. It does not block building the initial household planner.

## Documentation sources

- Kroger API reference: https://developer.kroger.com/reference/
- Walmart OPD introduction: https://www.walmart.io/docs/opd/stores/grocery-introduction

These establish the retailer feasibility boundaries; endpoint details and account entitlements must be verified during the corresponding implementation milestone.
