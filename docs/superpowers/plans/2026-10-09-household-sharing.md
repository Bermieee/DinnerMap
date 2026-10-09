# Household Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add separate accounts and safely shared household meal plans and grocery lists without enabling paid billing.

**Architecture:** Supabase Auth manages identity; PostgreSQL functions and row-level security manage household access and atomic edits. Riverpod switches between the existing local controller and a shared controller using explicit mutation commands, never whole-snapshot cloud saves. Realtime invalidates household-scoped cached records.

**Tech Stack:** Existing Flutter/Dart/Riverpod, official supabase_flutter SDK, PostgreSQL/pgTAP, Supabase CLI local services in CI.

**Spec:** `docs/superpowers/specs/2026-10-09-household-sharing-design.md`

## Global Constraints

- Android and web; every verified household member can edit and invite.
- One household per account initially; invitations expire after 24 hours and are single-use.
- No paid billing enabled; no external cloud project required for code/emulator delivery.
- Local mode remains separate; no silent upload on sign-in.
- Shared editing initially requires connectivity; cached shared records are read-only offline.
- No service-role credentials in Flutter; no passwords or invitation tokens in logs.
- Live completion requires configured free project and a two-account test; mocks do not prove live sharing.

## Review Focus

- Sign-out during a pending request: late responses cannot repopulate the old account's screen/cache.
- Two simultaneous redemptions: exactly one succeeds and neither account gains forged membership.
- Two household edits between fetch and save: unrelated records survive and same-record conflicts are visible.
- Regeneration while another member checks/adds groceries: current checkoffs/manual items survive atomically.
- Connection loss after submit: show uncertain save status, refetch before retry, and never duplicate manual items.

## File boundaries and common contracts

- `supabase/migrations/202610090001_household.sql`: identity, households, membership and invitation functions/policies.
- `supabase/migrations/202610090002_planner.sql`: record schema, validated atomic mutations and regeneration.
- `supabase/tests/household_test.sql`, `planner_test.sql`: database integration tests.
- `supabase/config.toml`: local auth, redirect and database settings; no secrets.
- `lib/features/household/account_models.dart`, `account_repository.dart`, `supabase_account_repository.dart`, `account_controller.dart`: identity and household lifecycle.
- `lib/features/household/household_screen.dart`: account/member forms and explicit local import.
- `lib/features/sync/shared_models.dart`, `shared_repository.dart`, `supabase_shared_repository.dart`: versioned records, commands and cloud transport.
- `lib/features/sync/shared_planner_controller.dart`, `shared_cache.dart`: shared editing, subscriptions and account-scoped read cache.
- `lib/features/planner/planner_controller.dart`: extract public editing contract; preserve local behavior.
- `lib/app.dart`, `lib/main.dart`: configuration, mode switch, state/error UI and Household screen replacement.
- `test/household/`, `test/sync/`: fake transport lifecycle/controller/widget tests.
- `.github/workflows/flutter.yml`, `docs/household-setup.md`, `README.md`: database CI, configuration, verified delivery status.

Common Dart types: `AccountSession(userId, email, verified)`, `Household(id, name)`, `HouseholdMember(userId, email)`, `HouseholdContext(session, household)`, `SharedRecord<T>(id, revision, value)`, `SharedView(snapshot, recordRevisions, online)`, `SharedConflict(recordId, currentRevision, currentValue)` and `SharedUnavailable(message, uncertain)`.

### Task 1: Account and membership security

**Interfaces:** RPC `create_household(p_name text) -> uuid`, `create_invitation() -> text`, `redeem_invitation(p_token text) -> uuid`, `leave_household() -> void`; read own context and member display emails through membership-filtered views/functions. Every function checks verified authenticated identity, uses a fixed search path, and is granted only to authenticated users.

- [ ] Write pgTAP tests: anonymous/unverified calls fail; verified creator gets exactly one membership; direct membership writes fail; outsider cannot read household/members/invitations; token expiry is 24 hours; second redemption fails; existing member cannot join another household; leaving removes access but retains content. Add a concurrent-session redemption integration script asserting one membership insertion for one token.
- [ ] Run `supabase start && supabase test db`; confirm missing-schema failures before implementation.
- [ ] Implement the first migration and local config. Use UUID keys, auth.users references, unique membership user ID, hashed cryptographically random tokens, restricted invitation storage, transactional row locks and server-side expiry. RLS membership checks use a narrowly scoped helper to avoid recursive membership policies. Limit names to 1–100 trimmed characters.
- [ ] Run database tests and concurrent redemption script; require all assertions passing. Commit schema/security and tests.

### Task 2: Atomic shared planner storage

**Interfaces:** RPC `read_shared_plan() -> jsonb`; `apply_shared_change(p_request_id uuid, p_change jsonb) -> jsonb`; `regenerate_shared_list(p_request_id uuid, p_calendar_revision bigint, p_start date, p_weeks int, p_rows jsonb, p_warnings jsonb) -> jsonb`; `import_local_plan(p_snapshot jsonb) -> void` only for an empty household. Commands include operation, record ID, expected revision and validated payload; replies carry server revisions. UUID request IDs prevent duplicate accepted operations after uncertain transport results.

- [ ] Write failing database tests for cross-household references, unknown fields, invalid dates/servings/quantities, conflicting expected revisions, two unrelated entry edits, duplicate manual request ID, checkoff updates, imported duplicate dates and nonempty import rejection. Regeneration tests assert manual items/current checkoffs survive and stale calendar revision aborts without partial writes.
- [ ] Run `supabase test db` and confirm missing function/schema failures.
- [ ] Implement the second migration: separate calendars/entries/recipes/lists/items/preferences, household IDs, audit fields, revisions and foreign keys. Validate existing domain serialization and dates 2020–2100, servings 1–100, weeks 1–4, finite positive amounts and piece weights at most 48 oz. Mutations lock the household calendar revision before dependent updates; regeneration and calendar mutations use the same lock order. Reject stale record revisions; shopping checkoffs use server acceptance order. Keep manual rows server-side during regeneration. RLS exposes only verified member records; direct mutation is denied in favor of RPC. Import is transactional and permitted only before any shared plan exists.
- [ ] Run all database tests; confirm access denial and conflict behavior through real PostgreSQL rather than mocked authorization. Commit.

### Task 3: Authentication and household lifecycle in Flutter

**Interfaces:** `AccountRepository`: `Stream<AccountSession?> watchSession()`, `Future<void> signUp(String email, String password)`, `signIn`, `signOut`, `resetPassword(String email)`, `updatePassword(String password)`, `Future<Household?> currentHousehold()`, `createHousehold(String name)`, `redeemInvitation(String token)`, `Future<String> createInvitation()`, `Future<List<HouseholdMember>> members()`, `leaveHousehold()`. `AccountController` owns loading/error states and exposes these operations without storing password fields.

- [ ] Write tests named `unverifiedCannotJoin`, `signOutInvalidatesLateContext`, `duplicateSubmissionDisabled`, `localPlanNotUploadedOnSignIn`, `verificationAndResetRedirectHandled`. Assert expired invite errors preserve input for retry and unsupported configuration preserves local mode.
- [ ] Run targeted Flutter tests in CI to confirm absent account classes fail; local Flutter bootstrap remains blocked and must not be retried.
- [ ] Implement repository/controller and official SDK transport. Initialize only when both `SUPABASE_URL` and `SUPABASE_ANON_KEY` compile-time values are provided. Use operation generation IDs to discard old session responses. Add verification/reset redirect handling on Android and web; generate platform configuration through `tool/setup.sh` reproducibly. Distinguish initial password reset from authenticated password update. Retain local repository independently.
- [ ] Implement Household screen with email/password forms, verification notice, reset, create/join, members, invite copy/share, leave and sign-out. Validate input, hide passwords and dispose text controllers. Show household content only after verified session/context is loaded.
- [ ] Run controller/widget tests and existing local tests; commit.

### Task 4: Shared commands, cache and conflict recovery

**Interfaces:** `SharedRepository`: `Future<SharedView> fetch()`, `Future<SharedView> apply(SharedCommand command)`, `Future<SharedView> regenerate(RegenerateCommand command)`, `Future<void> importLocal(PlannerSnapshot snapshot)`, `Stream<void> watchChanges()`, `dispose()`. `SharedCache`: `read(userId, householdId)`, `write(userId, householdId, SharedView view)`, `clearUser(userId)`. Extract `PlannerEditing` methods with the current controller's public names so screens need minimal change. Shared controller uses commands and expected record revisions, not `PlannerRepository.save(snapshot)`.

- [ ] Write tests asserting a single meal change sends one command; late replies after account switch are ignored; remote unrelated edits survive undo/randomize; same-meal conflict retains proposed value; offline commands make zero transport calls; lost connection after submit refetches before retry with the same request ID; sign-out clears only shared cache; realtime reconnect refetches.
- [ ] Run targeted tests and confirm failures.
- [ ] Implement versioned transport mapping and controller. Use sequential local submissions with per-command request UUIDs, catch database conflict codes and preserve draft proposals. Randomization/undo submit a batch of touched records with their expected revisions atomically; never restore an old full snapshot over remote changes. Track server-confirmed connectivity through subscription state and successful fetches; network failures enter read-only/uncertain state. Reconnect retries read, not mutation. Cache is read-only and explicitly scoped by identity/household; dispose subscriptions on context changes.
- [ ] Implement explicit local import preview with counts of meals/recipes/items, confirmation and empty-household server guard. Newly created empty shared plans offer import or an empty calendar; never automatically seed them through local controller load.
- [ ] Run sync tests plus existing local persistence/regeneration tests; commit.

### Task 5: Integrate shared UI and verify delivery

**Interfaces:** mode provider selects local or shared `PlannerEditing` and `AsyncValue<PlannerSnapshot>`; status provider exposes active mode, household name, saving/offline/conflict state. Existing screens consume that editing contract. Conflicts show current and proposed values with reload or reviewed reapply using the new revision.

- [ ] Write widget tests for create/join navigation, account switching, cached offline editing disabled, conflict reload/reapply, explicit import cancellation, session expiry and shared shopping checkoffs. Assert no overflow at 390×844 and 1280×900.
- [ ] Run tests to confirm missing mode/status integration fails.
- [ ] Integrate providers, header, shared status/error UI and disabled editing controls. Keep local backup export; shared backup restore uses guarded import, never full-snapshot replacement. Provide password-reset redirect routing and protect shared navigation during session transitions. Increment app build version for phone upgrade.
- [ ] Extend CI to start local Supabase, run database/concurrent tests, then Flutter formatting/analysis/tests, pure Dart checks and Android/web builds. Pin the tested SDK/CLI versions; do not use paid infrastructure. Run independent branch review after tests and address substantive findings.
- [ ] Write setup instructions covering free project SQL deployment, auth verification/reset redirects, Realtime table publication, public anon configuration, no service-role key, invitation privacy and free-plan limits. Record exact passed checks and remaining live validation. Publish a reviewable PR and APK without merging.
- [ ] With a configured project, run two-account create/join/edit/checkoff/reconnect/import-isolation validation on Android/web. If project access is unavailable, deliver emulator-verified code and state that live sharing remains unverified; do not call it deployed.

## Plan self-review

Membership, authentication and invitation lifecycle map to Tasks 1/3; versioned records, import and transaction integrity to Tasks 2/4; offline/cache/sign-out boundaries to Tasks 3/4/5; UI and all validation/delivery requirements to Task 5. All five review-focus failures have named database/controller tests. No live API, paid billing, household deletion or member-removal scope is introduced.
