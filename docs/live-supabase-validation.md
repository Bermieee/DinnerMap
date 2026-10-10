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
| Web registration/verification/reset | Email returns to exact hosted origin | User reports verification fixed; reset acceptance pending |
| Android verification/reset | Email returns to DinnerMap | User added callback; test pending |
| Household join | Two verified Supabase accounts see the same household | User reports pass on Fold5 |
| Meal edits both directions | Web edit appears on Android and vice versa | User reports takeout pass; recipe repair deployed, device acceptance pending |
| Grocery generation/checkoffs | Shared totals and checks update on both | Pending |
| Conflict/offline/sign-out | Conflicts require review; offline shared edits disabled; cache isolation | Pending |
| Layout/input | Phone, desktop, landscape, keyboard, large text, touch/mouse | Automated checks pass; user reports foldable layout adapts |
| Month lengths | 28/29/30/31 days, leap February, full-month shuffle | Automated checks pass |

Sites hosting selected for the existing compiled web version; separate owner-private deployment, with no new backend or secret keys. Managed browser QA is unavailable in this session.

First published web source: Sites commit b3e69dd7b5dec6d16a1cecac66a06909db725560, from configured GitHub artifact 11678259592. Verified ZIP digest, compiled project URL/publishable key, bootstrap/assets and deployment success. See the follow-up below for the current version and user-reported acceptance.

## 0.4.1 household usability follow-up

- Confirmed live shared data has one household, two memberships, three meals and zero recipes before repair.
- Migration adds bundled recipes to existing and future households, preserves existing IDs/edits/calendar, and keeps validated local import into untouched households available.
- New invitations use 12 cryptographically random base32 characters grouped as ABCD-EFGH-JKLM (60 bits); still hashed at rest, single-use, 24-hour expiry, verified-account/membership checks and creation rate limit. Existing 64-character invitations remain redeemable.
- Household screen adds a visible Account security section, password confirmation for signup/change, password reset controls and clearing secret fields on account changes.
- Database regression checks pass for recipe selection across members, preserved calendar/custom recipes, new/old invitations, expiry, authorization and import rollback. Review caught and fixed a stale-device import race: replaced visible recipes advance their record revisions and household revisions remain monotonic.
- Live migration applied successfully through Supabase. Verified 105 recipes, 3 meals and 2 memberships; before/after fingerprints for every meal and membership match exactly. Anonymous invitation creation and direct authenticated seeding/private import remain denied.
- All four jobs passed in CI run https://github.com/Bermieee/DinnerMap/actions/runs/38079163002 at remote code commit 8f6e637c52cdbda3661575fb591fbf2c1709e097: 89 Flutter tests, formatter/analyzer, standalone Dart checks, real PostgreSQL tests, retailer checks, web build and Android APK build.
- Web 0.4.1 published successfully, preserving owner-private access: Sites source commit 09993d33bb1b5e57cb0bc0b6693009d3b4f3f2a6, version 2, deployment appgdep_6aca90734298819199279ce67500ddd7. Web artifact 11679846127 ZIP SHA256 b28f9ab5ec23e164b960ca4540d143ab45958f59f12ac1bec5815a6293acc9a6. Compiled configuration, security controls and recipe assets verified. New interactions still need live device acceptance.
- Advisor review: 3 intentional private RLS tables without read policies and 10 authenticated, identity/membership-checked SECURITY DEFINER RPCs. Supabase breached-password protection is disabled and requires dashboard configuration: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection . Existing performance advisories remain (13 uncovered audit/relationship foreign keys and region profile RLS initplan); no new performance finding from this migration.
- Android artifact 11680016488 ZIP SHA256 c83c5bed1e085a25a11a85fea9fe428ec84e327cbcb0034dead8c462341c94da verified before extraction. APK is DinnerMap-0.4.1-test.apk (168431972 bytes), SHA256 4046a97f95b382b5101f2997a0e241b9c2a4b91a1849e37a0c87c5144920b9cf.
- Debug signing certificate differs from 0.4.0 (new SHA256 8aca19def94bbc94e342f81f06a906c0b130fc9101e50671ce0dc3301d8e09f0; previous 49d08518a59a0cee4c75dc2410036606105a3d0cfd1d4eeda1b1a3829f42140c). Android requires removing the older test install first; export any local-only plans before uninstalling, then sign back into the existing shared account. Shared household data stays on Supabase. Stable release signing/Google Play distribution remains pending.
