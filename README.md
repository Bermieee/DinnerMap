# DinnerMap

Flutter meal planning and grocery lists for Android and web. Household sharing and official Kroger/Walmart connections are the next stages.

## Foundation features

- Responsive dark calendar, dated meal scheduling, recipe replacement, takeout/leftovers, cooked markers, notes and undo.
- 105 attributed offline recipes, recipe search, favorites, shuffle avoidance and manual recipe editing.
- Cumulative 1–4 week shopping totals, compatible unit conversion, pounds/ounces and editable per-piece weight estimates.
- Local saved data, checklist items, manual groceries, regeneration, TXT/CSV export and JSON backup/restore.
- Retailer interfaces and tested lowest/highest price sorting logic; live product results and cart transfer are not connected.

This version is explicitly a **local demo**. Data stays in the current browser/device. Accounts, invitations and cross-device sync are not implemented. Browser storage can be cleared; export backups for important plans.

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

GitHub Actions generates platform files, resolves dependencies, analyzes, tests and builds a downloadable web artifact. Android builds require an Android SDK.

## Recipe and calculation limitations

Recipes retain source links and original ingredient measurements. Full cooking directions are at the linked source. Most imported base serving counts are unknown: quantities stay at the original recipe yield until users confirm that count in the recipe editor. Ambiguous amounts remain visible with warnings. Volume does not convert to mass without a density. Count weights are estimates.

The demo starts with 28 offline recipes, selected from the prototype's curated library, rather than fetching its online starter calendar. The exact original prototype remains in `reference/`. Review recipe redistribution rights before public release.

## Design and plan

- [Design](docs/superpowers/specs/2026-10-09-dinnermap-design.md)
- [Foundation plan](docs/superpowers/plans/2026-10-09-dinnermap-foundation.md)
- [Original HTML prototype](reference/monthly-meal-planner-v13.html)

## Hosting

Flutter is free. No paid service has been configured. Select the account/sync backend after comparing current free quotas and billing requirements. Retailer secrets must stay on a backend; Walmart grocery API access requires approval.

## Verification status

Standalone Dart checks and static analysis of the pure domain/data code pass. Full Flutter analysis, widget tests and builds require CI verification; the source is a draft until those checks pass. Local Flutter bootstrap was stopped by automatic approval review for cloud metadata access.

Known foundation gaps: Browser/native printing and system sharing are wired through Flutter plugins; platform dialogs require manual device verification.
