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
- [ ] Write and run failing tests: five-digit ZIP incl 00501, invalid radius, owner isolation, ZIP replacement clears store, stale result dropped.
- [ ] Implement models, controller and SQL ownership/rate limit.
- [ ] Run domain and database checks; commit.

### Task 2: Retailer backend
Files: supabase/functions/retailers/core.mjs, index.ts; tool/retailers/core_test.mjs.
Interfaces: createRetailerService(fetch, credentials), dispatch(action,args), normalized region/store/offer payload.
- [ ] Fail tests for ZIP resolution, Kroger store and multiple-item price mapping, provider failure, bounded requests and missing credentials.
- [ ] Implement server normalization, token caching and timeout; authenticated entrypoint with database rate limiting and ZIP cache.
- [ ] Run Node tests; commit.

### Task 3: Flutter store flow
Files: regional repositories/providers/screen; lib/app.dart and lib/main.dart; test/region/region_screen_test.dart.
- [ ] Fail widget checks: invalid ZIP cannot save, profile persists, unavailable providers visible, product sort/selected store context.
- [ ] Implement local/Supabase persistence, account-scoped providers and adaptive Stores screen via Household action.
- [ ] Run formatting/analyzer/Flutter tests in CI, all regression suites and web/Android packaging.
- [ ] Independent review then regression fixes; publish draft PR without merging.

### Task 4: Delivery
- [ ] Version 0.4.0+4, configuration guide and privacy notes.
- [ ] Publish exact full repository tree and verify CI artifact commit. Report live configuration requirements separately.
