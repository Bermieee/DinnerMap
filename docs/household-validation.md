# Household sharing validation

Validated source: remote commit `1cf9fd3c1b580b433a14c01fefa18678bf902e06`, GitHub Actions run https://github.com/Bermieee/DinnerMap/actions/runs/37997701259 .

- Flutter analysis passes with `--no-fatal-infos`: no warnings/errors; 77 informational style messages.
- Flutter tests: 35 passed.
- Standalone Dart domain/storage/account/command checks: 28 passed.
- Real PostgreSQL 17 security/storage/concurrency checks: 47 passed.
- Web build and Android debug APK build both passed; artifacts are in the linked run.
- Independent whole-branch review found five Important issues. All were fixed in one pass: stale recipe drafts require review, deleted groceries emit no orphan check commands, refresh completes before mutation/retry, regeneration errors retain their proposal/request, and database reads lock the household for coherent values/revisions. Regressions failed before the fixes and passed afterward.

## Implementation decisions

- Continue in the dedicated checkout on a separate feature branch, rather than create another worktree. Existing isolation was sufficient; no shared main checkout was modified. If more editors share this checkout, they need independent isolation.
- Local Docker/Supabase CLI and OS PostgreSQL installation were unavailable. Use pinned PGlite locally and an ephemeral PostgreSQL 17 container in CI with an auth-schema fixture. This tests actual SQL policies/transactions, including separate-session races in CI. It does not establish hosted Auth/Realtime behavior.
- The initial household has one calendar and one saved grocery list, matching the current UI. Multiple calendars/lists require a schema/selector extension rather than assuming they already work.
- Deliver source and setup instructions before live acceptance because no Supabase project is configured. Hosted Auth/Realtime, email verification/reset redirects and a two-account Android/web flow remain unverified. Those integrations may need fixes before sharing is used.

## Deferred limitation

Offline shared screens currently disable browsing interactions as well as edits. Cached data remains displayed, but scrolling/search/details should be restored by disabling mutation controls individually in a follow-up UI pass. System printing/sharing dialogs also still need device verification from the original foundation.

No paid billing, retailer connections, production signing or public launch was configured. The draft PR targets the foundation branch; neither PR has been merged.
