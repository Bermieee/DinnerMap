# Regional Shopping Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. User authorized starting this milestone; avoid repeating the prior approval loop.

**Goal:** Private ZIP profiles, store discovery and store-specific product comparisons.
**Architecture:** Flutter regional models/controller and repositories; Supabase profile tables/RLS and authenticated retailer Edge Function. Provider secrets remain server-side.
**Tech Stack:** Flutter/Riverpod, Dart, PostgreSQL, TypeScript-compatible JavaScript, Supabase.
**Spec:** docs/superpowers/specs/2026-10-10-regional-shopping-design.md

## Global Constraints
US ZIP as five digits; radius 5–100 miles default 25; location personal, household planner shared; no automatic ZIP assignment; no cart transfer. No live provider deployment or billing.

## Review Focus
Account changes during requests; unresolved ZIPs; multiple item sizes per product; unknown/zero prices; wrong unit families in comparisons.

### Task 1: Region profiles and security
Files: lib/features/region/region_models.dart, region_repository.dart, region_controller.dart; supabase/migrations/202610100001_region.sql; tool/database/region_test.mjs; tool/region_check.dart.
Interfaces: RegionProfile(zip, radiusMiles, selectedStoreId), RegionRepository load/save/resolve/stores/search, RegionController account-scoped state and async commands.
- [x] Write and run failing tests: five-digit ZIP incl 00501, invalid radius, owner isolation, ZIP replacement clears store, stale result dropped.
- [x] Implement models, controller and SQL ownership/rate limit.
- [x] Run domain and database checks; commit.

### Task 2: Retailer backend
Files: supabase/functions/retailers/core.mjs, index.ts; tool/retailers/core_test.mjs.
Interfaces: createRetailerService(fetch, credentials), dispatch(action,args), normalized region/store/offer payload.
- [x] Fail tests for ZIP resolution, Kroger store and multiple-item price mapping, provider failure, bounded requests and missing credentials.
- [x] Implement server normalization, token caching and timeout; authenticated entrypoint with database rate limiting and ZIP cache.
- [x] Run Node tests; commit.

### Task 3: Flutter store flow
Files: regional repositories/providers/screen; lib/app.dart and lib/main.dart; test/region/region_screen_test.dart.
- [x] Fail widget checks: invalid ZIP cannot save, profile persists, unavailable providers visible, product sort/selected store context.
- [x] Implement local/Supabase persistence, account-scoped providers and adaptive Stores screen via Household action.
- [x] Run formatting/analyzer/Flutter tests in CI, all regression suites and web/Android packaging.
- [x] Independent review then regression fixes; publish draft PR without merging.

### Task 4: Delivery
- [x] Version 0.4.0+4, configuration guide and privacy notes.
- [x] Publish exact full repository tree and verify CI artifact commit. Report live configuration requirements separately.

## Execution ledger

Task 1: complete — ZIP leading zeroes/invalid values, selection clearing and disposed responses tested; standalone region checks 16/16; region database checks 13/13. Local commits 753be36..7569897 and review regressions through e275cd8.
Task 2: complete — Node connector/handler tests RED→GREEN, 14/14; Deno function type check green in CI38021996737. Local commits 7569897..1179ef0 plus normalization review fixes de0b866.
Task 3: complete — screen implementation and independent review/regression fixes complete; full Flutter suite 86/86, formatting/analysis, Dart57/57, PostgreSQL60/60, Node14/14, Deno type check and Android/web builds passed in CI38021996737 at f3faf09972d284845aac68a9887623bf221e6bfa.
Task 4: complete — version 0.4.0+4, setup/privacy guidance and pinned Android/web artifact evidence published. Draft PR4 targets feat/adaptive-layouts and remains unmerged. No live backend, retailer, Google Play or billing configuration was performed.

Decisions and their costs are recorded as Ruling lines in docs/regional-shopping-validation.md. Scope follows the existing agreed milestone; no new paid service or live deployment was configured.
