# DinnerMap continuity recovery

## Latest update — Kroger-family integration, 0.6.3+14

Source `10164973ed8a6de3417ab61541286184a62f97ba` is saved on `feat/regional-shopping` in draft PR4. CI38119733338 passed110 Flutter tests, analysis, database, retailers, native/browser checks and the configured web build. The existing retailer Edge Function is now version7, ACTIVE, verify_jwt=true; anonymous POST remains401. Discovery retains local chain names from ZIP/radius results and shows the selected location in pricing. No additional chain credentials or database migration is needed.

**Live web remains0.6.2:** publication is blocked by the disconnected workspace execution environment (409 environment_offline). The0.6.3 web artifact11695445029 is ready in CI38119733338; ZIP SHA256 `1c74d98f088de24a0a3a5041a784a4bf2c1942173d6dc042662a3ce0be101508`. Resume publication using the existing Sites project and tested artifact. Android is still building at this checkpoint. Do not redo Supabase setup. See regional-shopping-validation.md for exact verification and resume details.

Recovered October 11, 2026, approximately 02:23 America/New_York. This note reconstructs project context from source, validation records, live read-only checks, and user reports. It does not restore missing ChatGPT messages.

## Recovery checkpoint (superseded by the update above)

- Runtime version: **0.6.2+13** on `feat/regional-shopping`.
- Remote documentation head before this note: `5d516433ae55e543c9e84a1b96143d078070006d`.
- Tested code: `3f4e242c79f6bf1bd901d9feed97f476099bee3a`.
- [CI 38100886738](https://github.com/Bermieee/DinnerMap/actions/runs/38100886738): checks, database, retailers, and Android jobs all completed successfully.
- Live website: https://dinnermap-web.lushsnail1.chatgpt.site/
- Sites project: `appgprj_6aca85cdb0208191af6166428b56d663`. Read-only check confirms active, version 10, custom access.
- Recorded 0.6.2 deployment: `appgdep_6acae2efa26881919b753e39d30a6809`, succeeded October 10 at 21:14 EDT.
- Work remains on stacked draft PRs #1–#4. Main contains the initial scaffold; do not mistake main-only history for the latest implementation.

## Supabase setup recovered

Project `cmrfydajyhoctunacdvi` is the existing backend. Do not create another project or repeat setup merely because chat history is missing.

Fresh read-only checks confirm:
- Project ACTIVE_HEALTHY; PostgreSQL 17.
- RLS enabled on all nine public tables: households, memberships, recipes, calendar_entries, household_preferences, shopping_lists, shopping_items, zip_regions, region_profiles.
- Realtime includes the seven household/planner tables, including recipes and calendar entries.
- Retailers Edge Function ACTIVE, version 6, verify_jwt=true.
- Migration ledger contains region profiles/cache, Realtime, household usability and recipe discovery.
- Live private.apply_one contains clearList support. The user applied that SQL manually, so ledger absence is not evidence that it is missing.

Earlier recorded verification established email confirmation enabled, anonymous shared commands rejected, and public client configuration without service-role secrets. Those Auth settings were not freshly reread in this recovery pass.

Kroger client credentials were configured in backend secrets by the user. Initial secret-name mismatch was corrected. Never copy credential values into source, client builds or notes.

## Recovered milestones

| Version | Result |
| --- | --- |
| 0.3.0 | Adaptive phones/tablets/fold layouts, actual calendar month lengths, offline browsing, conflict/context guards. |
| 0.4.0 | Private account ZIP/radius, nearby Kroger stores and selected-store product search. |
| 0.4.1 | Signup/change/reset password controls; 12-character grouped invite codes; starter recipe seeding for households; stale-device import fixes. |
| 0.4.2 | Search and region/diet/meal-prep filters in both recipe library and dinner picker; 108 starter recipes. |
| 0.4.3 | Fixed browser dietary-label comparison; vegan and vegetarian remain distinct. |
| 0.5.0 | Reviewed Kroger product choices and partial list package-cost estimates. |
| 0.5.1 | Cooking-friendly quantities and whole-package recommendations; original precise recipe quantities retained. |
| 0.5.2 | Remove preparation terms from retail queries, such as cubed chicken, while keeping recipe identity. |
| 0.6.0 | Whole-list Kroger deal suggestions with progress, cancellation and explicit review. |
| 0.6.1 | Clear saved grocery list and stale quotes; shared conflict guard; cleaned shopping labels. |
| 0.6.2 | Full catalog ingredient audit and matching/conversion diagnostics fixes. |

Short invitations have 12 random base32 characters, displayed like ABCD-EFGH-JKLM; hashes stored, single use, 24-hour expiry. Existing long invitations remain redeemable.

Latest ingredient audit covers 108 recipes, 607 distinct ingredient names and 1,430 ingredient lines. Fixes address corrupted boneless/skinless plurals, BBQ aliases, ground pepper, preparation/use qualifiers, package units and supported density conversions. Unknown quantities or ambiguous products require review.

## User-reported live acceptance

These are user reports, distinct from automated tests:
- Web verification redirect fixed.
- Wife joined the household on a Fold 5; layout adapted.
- Calendar synced both directions.
- Recipes visible and accessible across accounts.
- Kroger found and selected a nearby store; initial integration worked.
- Clear-list SQL returned Success, no rows returned.

Do not downgrade these to setup-not-started because earlier validation sections list them as pending.

## Remaining verification and scope

- Rerun the full current grocery list against Kroger on 0.6.2 and inspect per-row diagnostics. Passing builds do not prove current store inventory matches.
- Latest clear-list button behavior and Android cold-start email callback still need device acceptance.
- Specific Yahoo verification-delivery issue has no confirmed resolution in available records.
- Live password reset/change acceptance and current breached-password protection setting remain unverified.
- Quotes are session-only. Deal ranking uses up to 50 returned offers, requires review, and does not allocate one package across separate rows.
- Only Kroger is integrated. Walmart/Amazon and whole-list multi-vendor comparison remain future work.
- Google Play setup/release signing remains separate from the debug Android CI build.
- Missing conversation text and every intermediate decision cannot be reconstructed from source alone.

## Authoritative supporting notes

- [Live Supabase validation](live-supabase-validation.md)
- [Household setup](household-setup.md) and [validation](household-validation.md)
- [Adaptive layout validation](adaptive-layout-validation.md)
- [Regional shopping setup](regional-shopping-setup.md) and [validation](regional-shopping-validation.md)
- [Ingredient search audit](ingredient-search-audit.csv)

Read later appended checkpoints before treating an early pending/blocker section as current. Recovery work changed no live configuration or user data.

