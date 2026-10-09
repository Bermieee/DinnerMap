# DinnerMap

Flutter meal planning and grocery lists for Android and web. Optional Supabase accounts and household sharing are implemented in the sharing branch; official Kroger/Walmart connections are the next stage.

## Foundation features

- Responsive dark calendar, dated meal scheduling, recipe replacement, takeout/leftovers, cooked markers, notes and undo.
- 105 attributed offline recipes, recipe search, favorites, shuffle avoidance and manual recipe editing.
- Cumulative 1–4 week shopping totals, compatible unit conversion, pounds/ounces and editable per-piece weight estimates.
- Local saved data, checklist items, manual groceries, regeneration, TXT/CSV export and JSON backup/restore.
- Retailer interfaces and tested lowest/highest price sorting logic; live product results and cart transfer are not connected.

Without backend configuration, this version runs as a **local demo** and data stays on the current browser/device. Browser storage can be cleared; export backups for important plans.

## Household sharing

The optional Supabase backend adds email/password accounts, verified household membership, single-use invitations, shared meal/recipe edits and grocery checkoffs. Every member can edit and invite. Choose local or shared mode explicitly; local data never uploads on sign-in. Import into an empty household requires a preview/confirmation. Shared edits require connectivity, with cached data and reviewed conflicts.

See [household setup](docs/household-setup.md) for migrations, free-project configuration, redirect URLs and configured builds. Default CI artifacts contain no Supabase project configuration, so sharing is not live in those APKs. No paid billing has been enabled. One calendar and one saved grocery list per household are supported initially.

## Run

Install the free [Flutter SDK](https://docs.flutter.dev/get-started/install), then:

```bash
bash tool/setup.sh
flutter run -d chrome
# Or with an Android device/emulator connected:
flutter run
```

`tool/setup.sh` generates Android/web platform files with the installed stable Flutter SDK without replacing application source. No Firebase project or billing account is required.

## Validate

```bash
flutter analyze
flutter test
dart tool/domain_check.dart
dart tool/storage_check.dart
flutter build web
flutter build apk --debug
```

GitHub Actions validates an ephemeral PostgreSQL database, generates platform files, resolves dependencies, analyzes, tests, and produces downloadable web and Android artifacts.

## Recipe and calculation limitations

Recipes retain source links and original ingredient measurements. Full cooking directions are at the linked source. Most imported base serving counts are unknown: quantities stay at the original recipe yield until users confirm that count in the recipe editor. Ambiguous amounts remain visible with warnings. Volume does not convert to mass without a density. Count weights are estimates.

The demo starts with 28 offline recipes, selected from the prototype's curated library, rather than fetching its online starter calendar. The exact original prototype remains in `reference/`. Review recipe redistribution rights before public release.

## Design and plan

- [Design](docs/superpowers/specs/2026-10-09-dinnermap-design.md)
- [Foundation plan](docs/superpowers/plans/2026-10-09-dinnermap-foundation.md)
- [Original HTML prototype](reference/monthly-meal-planner-v13.html)

## Hosting

Flutter is free. No paid service has been configured. Supabase is the selected optional account/sync backend; check its current free quotas before deployment. Retailer secrets must stay on a backend; Walmart grocery API access requires approval.

## Verification status

The initial local foundation passed Flutter tests and Android/web builds, and the user confirmed meal editing and grocery generation on an Android phone. The sharing branch adds database security/concurrency and Flutter sync regressions; inspect its latest [CI run](https://github.com/Bermieee/DinnerMap/pull/2/checks) for current results.

Hosted Supabase Auth/Realtime, email delivery/redirects and a live two-account flow require a configured project and remain unverified. Local Flutter bootstrap was blocked by automatic approval review; validation uses isolated GitHub CI and safe standalone Dart checks.

Known limitations: Shared offline mode currently blocks browsing interactions as well as edits; refining mutation-only disabled controls is deferred. Printing/system sharing dialogs still need manual phone verification. No live retailer prices/cart transfer or public deployment is provided.
