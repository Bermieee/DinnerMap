# DinnerMap household sharing

## Outcome

The Android foundation has been tested on the user's phone: meals change and grocery lists generate. The next milestone lets separate accounts share a household calendar, recipes and saved shopping lists. Every member can edit and invite. The app remains usable locally without a configured backend. No paid billing is enabled.

## Provider decision

Recommend Supabase Auth, PostgreSQL, row-level security and Realtime. Its free plan currently includes 50,000 monthly active users, a 500 MB database and 5 GB egress; inactive free projects may pause after one week. These are provider limits, not a promise that a public release stays free. Firebase remains a viable alternative with strong offline persistence, but deploying its Cloud Functions requires Blaze billing. A self-hosted backend adds operations before the household flow works.

This replaces the earlier candidate Firebase backend only after user review. Supabase project creation/configuration is a later deployment step; implementation includes SQL migrations, application code and setup instructions without creating a billed resource.

Sources checked October 9, 2026:
- https://supabase.com/pricing
- https://supabase.com/docs/guides/getting-started/tutorials/with-flutter
- https://firebase.google.com/docs/functions/get-started

## Accounts and household lifecycle

Email/password registration, email verification, sign-in, sign-out and password reset use Supabase Auth. Passwords never enter application logs or domain storage. Configure Android and web redirect URLs for verification and reset. Unverified users cannot create or join households. A signed-in account belongs to at most one household initially.

Members create a named household or redeem an invitation. A database function creates a cryptographically random single-use token, stores only its hash and expires it after 24 hours. Redemption checks authentication, verification, expiry and existing membership atomically. Tokens grant access only to their household and are never exposed through table reads. All members may invite and edit. Leaving revokes access; shared content remains. Member removal and household deletion are deferred.

## Shared records and authorization

Store profiles, households, memberships, calendars, calendar entries, recipes, shopping lists and shopping items in separate tables. Each shared record includes household ID, creator/updater, server timestamps and a revision. Meal entries are unique by calendar/date; grocery items are individual records. Favorites and avoided recipes are household preferences for this milestone, consistent with the current planner's saved state.

Enable row-level security on every exposed table. Access requires an authenticated, verified household member. Membership creation and invitation operations run only through constrained database functions with a fixed search path. Clients cannot directly write memberships or invitation records. Server validation enforces dates, positive quantities, serving bounds and compatible record ownership. Use foreign keys and household-aware validation to prevent cross-household references. Never ship service-role credentials in Flutter.

## Sync, conflicts and local data

Keep the existing local planner as a separate mode. Signing in never silently uploads its contents. A new household may explicitly import a previewed local backup once; joining an existing household loads its shared data. Show the active household or local mode in the app header.

Read shared records into the existing domain models. Subscribe to household changes and reload affected records; reconnect performs a fresh fetch. Persist a cache scoped by account and household. On sign-out, clear that account's shared cache and subscriptions while retaining the separate local planner.

Shared editing initially requires connectivity. Cached shared records remain readable offline, with a clear offline label; edits are disabled until connection returns. This deliberately changes the earlier Firestore-specific offline proposal and avoids claiming queued offline writes are implemented.

Meal and recipe mutations use expected-revision comparisons in database transactions. A conflicting edit returns the current record and offers reload or review/reapply. Never save the entire snapshot over another member's updates. Checklist toggles use the latest accepted server update. Regeneration is one transaction: replace recipe-derived amounts, retain current manual items and checkoffs, and compare the source calendar revision. Concurrent calendar changes cause a retry prompt instead of a falsely current list.

## UI and recovery

Replace the Household placeholder with account forms, household create/join, members, invitation creation/copy and leave/sign-out actions. Use progress/error states and disable duplicate submissions. Planner navigation stays familiar. Surface connection loss, session expiry, conflicts and failed saves without discarding the user's proposed edit. Retailer connections remain unconnected.

## Validation and delivery

Database integration tests cover anonymous access, unverified accounts, cross-household reads/writes, forged memberships, expired/reused invitations, concurrent redemption, record references, revision conflicts and regeneration races. Flutter tests cover account state, explicit local import, sign-out isolation, offline read-only behavior and conflict recovery. CI runs those checks plus existing calculation/storage/widget tests and Android/web builds.

Deliver a reviewable PR and APK. Completion of the live milestone requires a configured free project and a two-account test: create/join, change meals on both devices, see shared checkoffs, reconnect and confirm persistence. Until then, report code/emulator validation separately from live sharing. No Kroger/Walmart credentials, checkout, paid billing or public launch are part of this milestone.
