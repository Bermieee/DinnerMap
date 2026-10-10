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

## Advisor review

The security advisor reports intentional authenticated SECURITY DEFINER RPC endpoints and private tables with no read policies. These are deliberate: RPC bodies check verified identity and membership, direct shared writes are denied, and private invitation/request tables are not client-readable. See https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable and https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy . Do not remove command authorization to silence these notices.

## Pending

- Allow com.dinnermap://auth-callback/ in Auth URL configuration. Current connector does not expose Auth config read/write, and browser authentication remains incomplete; this setting has not been verified or changed.
- Hosted web URL and its exact Auth redirect need a hosting destination.
- Verified two-account Android/web acceptance remains pending. No real accounts or emails were created by the agent.
- Kroger client credentials remain pending; ZIP resolution has not yet been tested with a verified user.
- Google Play release signing/upload remains pending. Debug APK is for development testing.
