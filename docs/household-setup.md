# Household sharing setup

This branch adds optional Supabase accounts and shared records. An unconfigured APK continues in local mode. Building code and testing PostgreSQL are separate from deploying a live household backend.

## Free project

Create a Supabase project on the Free plan. Do not upgrade or attach paid services for this milestone. Check https://supabase.com/pricing for current limits; free projects can pause after a week of inactivity. Choose a region near the household. Keep the database password private.

In the SQL editor, run the migrations in order:

1. `supabase/migrations/202610090001_household.sql`
2. `supabase/migrations/202610090002_planner.sql`

Use these on a new DinnerMap project. Do not rerun them on an unrelated database. Both migrations enable row-level security and restrict mutation to validated functions. Enable Realtime replication for `households`, `memberships`, `calendar_entries`, `recipes`, `household_preferences`, `shopping_lists` and `shopping_items` in Database → Replication. Clients subscribe only to their household.

In Authentication, enable email/password and email confirmation. Allow `com.dinnermap://auth-callback/` as a redirect for Android, and the exact served web-app URL for web. Set the Site URL to the web URL. Configure production email delivery before inviting public users; verify the provider's current email limits. Passwords are managed by Supabase Auth.

## Build configuration

The Supabase project URL and client anon/publishable key are public client configuration. Database permissions still enforce household access. **Never use a service-role/secret key in Flutter or a committed configuration file.**

With Flutter installed:

```bash
bash tool/setup.sh
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_CLIENT_KEY
flutter build apk --debug --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_CLIENT_KEY
flutter build web --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_CLIENT_KEY
```

GitHub test artifacts now use config/dinnermap-test.json to connect to the configured DinnerMap test project. This file contains only public client configuration; it must never contain secret/service-role keys. A build without these defines remains in local mode. The Android setup script adds the auth callback intent and Internet permission. Serve web output using HTTPS. Do not distribute debug APKs as a production release.

## Household flow

1. Open Household, create an account, verify email, and sign in.
2. Create a household and explicitly choose **Use shared household**.
3. If desired, preview and import the local phone plan into the empty household. Signing in never uploads it automatically. Imported grocery lists remain marked stale until regenerated.
4. Create an invitation, copy its token and give it to the intended member. Tokens expire after 24 hours, are single-use, and grant editing access. Do not post them publicly.
5. The second verified account redeems the token and chooses the shared household.
6. Every member can edit meals/recipes, generate groceries and check items. Conflicts require review; cached shared records are read-only when offline.
7. Leaving or signing out returns to local mode. Household data remains for other members. Signing out clears that account's shared cache; local data stays separate.

## Validation

```bash
cd tool/database
npm ci
npm test
```

The default tests run real PostgreSQL via PGlite. Set `DATABASE_URL` to an isolated PostgreSQL test server to exercise separate-session invitation redemption. The test runner creates and drops uniquely named databases and creates test roles. **Never point DATABASE_URL at a production database server.** CI uses an ephemeral PostgreSQL 17 container.

Flutter checks: `flutter analyze --no-fatal-infos`, `flutter test`, `dart tool/domain_check.dart`, `dart tool/storage_check.dart`, `dart tool/account_check.dart`, `dart tool/shared_check.dart`, plus Android and web builds. The account controller and command mapping also run with standalone Dart.

Before calling live sharing complete, test two real accounts on Android/web: verify emails, create/join, edit meals from both clients, generate groceries, see each other's checkoffs, reconnect, and sign out without showing the other account's cache. Confirm verification and password reset redirects on a cold-start Android app and the hosted web URL. Database fixture tests do not validate hosted email delivery or redirect handling.

Kroger/Walmart remain unconnected. Public-release work includes account deletion, privacy/terms, abuse controls, quota monitoring, release signing and recipe redistribution review.
