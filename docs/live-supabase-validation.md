# DinnerMap live Supabase checkpoint — 2026-10-10

Project: cmrfydajyhoctunacdvi (active, PostgreSQL 17).

## Applied and verified

- Existing household and planner schemas found with RLS enabled.
- Region profiles/ZIP cache migration applied through connected Supabase tools.
- Realtime publication includes households, memberships, calendar_entries, recipes, household_preferences, shopping_lists and shopping_items.
- Retailers Edge Function version 1 deployed ACTIVE with verify_jwt=true. Function body independently verifies user and email confirmation.
- Public Auth settings: email enabled; signup permitted; mailer_autoconfirm=false.
- Live unauthenticated POST to retailers rejects with 401; read_shared_plan rejects with 401/permission denied. Anonymous region_profiles read returns an empty array. Anonymous role cannot execute any of seven shared command functions.
- Build configuration uses the project URL and modern publishable key, never a secret or service-role key.

- Configured Android and web builds plus all checks passed in CI run 38075720061 at remote code commit 1a6b5ad561bc4a6540b71175aef5b9784c86f6c6. Android artifact 11678615629; web artifact 11678259592.

## Advisor review

The security advisor reports intentional authenticated SECURITY DEFINER RPC endpoints and private tables with no read policies. These are deliberate: RPC bodies check verified identity and membership, direct shared writes are denied, and private invitation/request tables are not client-readable. See https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable and https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy . Do not remove command authorization to silence these notices.

## Pending

- Android callback com.dinnermap://auth-callback/ added by the user on 2026-10-10. Reported complete; live email-return flow remains untested.
- Web published privately at https://dinnermap-web.lushsnail1.chatgpt.site (Sites version 1; deployment appgdep_6aca864702408191ac761612b3867c8e succeeded). User reports fixing the web verification return URL.
- User reports wife joined the household on Fold5, adaptive layout worked, and calendar edits synchronized in both directions. Recipe meals were blocked by an empty shared recipe library; takeout synchronized. No real accounts or emails were created by the agent.
- Kroger client credentials remain pending; ZIP resolution has not yet been tested with a verified user.
- Google Play release signing/upload remains pending. Debug APK is for development testing.

## Cross-platform acceptance — next session

Use shared household mode on both clients; local device plans do not sync automatically. Import one local plan into an empty household only after preview/confirmation.

| Check | Expected | Status |
| --- | --- | --- |
| Web registration/verification/reset | Email returns to exact hosted origin | Pending web redirect |
| Android verification/reset | Email returns to DinnerMap | User added callback; test pending |
| Household join | Two verified Supabase accounts see the same household | User reports pass on Fold5 |
| Meal edits both directions | Web edit appears on Android and vice versa | User reports takeout pass; recipe fix in progress |
| Grocery generation/checkoffs | Shared totals and checks update on both | Pending |
| Conflict/offline/sign-out | Conflicts require review; offline shared edits disabled; cache isolation | Pending |
| Layout/input | Phone, desktop, landscape, keyboard, large text, touch/mouse | Automated checks pass; user reports foldable layout adapts |
| Month lengths | 28/29/30/31 days, leap February, full-month shuffle | Automated checks pass |

Sites hosting selected for the existing compiled web version; separate owner-private deployment, with no new backend or secret keys. Managed browser QA is unavailable in this session.

Published web source: Sites commit b3e69dd7b5dec6d16a1cecac66a06909db725560, from configured GitHub artifact 11678259592. Verified ZIP digest, compiled project URL/publishable key, bootstrap/assets and deployment success. Interactive hosted/cross-platform results are not yet established.

## 0.4.1 household usability follow-up

- Confirmed live shared data has one household, two memberships, three meals and zero recipes before repair.
- Migration adds bundled recipes to existing and future households, preserves existing IDs/edits/calendar, and keeps validated local import into untouched households available.
- New invitations use 12 cryptographically random base32 characters grouped as ABCD-EFGH-JKLM (60 bits); still hashed at rest, single-use, 24-hour expiry, verified-account/membership checks and creation rate limit. Existing 64-character invitations remain redeemable.
- Household screen adds a visible Account security section, password confirmation for signup/change, password reset controls and clearing secret fields on account changes.
- Local database regression checks pass for recipe selection across members, preserved calendar/custom recipes, new/old invitations, expiry, authorization and import rollback. Flutter/build verification and live deployment pending.
