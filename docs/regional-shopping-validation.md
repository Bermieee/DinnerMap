# Regional shopping validation

## Scope
Private account ZIP/radius preferences, ZIP metadata resolution/cache, Kroger location discovery and selected-store product search. Local device ZIP saving is available without a backend. Walmart and Amazon are explicitly unavailable. No deployed backend or retailer credentials have been configured.

## Automated evidence
Version **0.4.0+4**, code commit `f3faf09972d284845aac68a9887623bf221e6bfa` (local `e275cd8`), is validated by [CI 38021996737](https://github.com/Bermieee/DinnerMap/actions/runs/38021996737).

- 86 Flutter tests passed, including ZIP validation/saving, store selection, product results, empty-search feedback, small phones/landscape/tablets with doubled text, and the header/form in the larger fold region. All prior planner/sharing/layout regressions remain green.
- Formatting and analysis passed: 108 informational lints, no warnings or errors.
- 57 standalone Dart checks passed (41 prior checks plus 16 regional checks).
- 60 PostgreSQL checks passed (47 existing security/storage/concurrency plus 13 regional ownership/rate-limit checks).
- 14 Node retailer/handler tests passed; deployed Edge Function type checking passed with Deno 2.9.6.
- Web build passed. [Web artifact](https://github.com/Bermieee/DinnerMap/actions/runs/38021996737/artifacts/11658453266), archive SHA-256 `15e38863098d56f22dd3a683d7844d6f609af30a720b69ade858687df5d359f2`.
- Android debug APK build passed. [Android artifact](https://github.com/Bermieee/DinnerMap/actions/runs/38021996737/artifacts/11658089405), archive SHA-256 `e4cb923b8e6495b12262469021700342bf2ec7867f2ad6570b5f588ec7222d91`. Both artifacts are pinned to the validated code commit. Subsequent evidence updates change documentation only.

RED evidence: CI 38020890591 passed 79 prior tests and failed the two new store-screen tests before screen implementation. Local backend tests reproduced missing ZIP/error/token/normalization behavior before implementation; authenticated handler tests reproduced missing authorization, quota, cache and input guards. CI 38021665347 reproduced small large-text overflow and the header outside the largest fold region; both pass in the final code run.

## Review and decisions
Independent review found no Critical findings. I regraded the two malformed-provider response findings as Important because one corrupt row could hide valid store/product results. Tests reproduced both failures before filtering malformed items and normalizing optional store fields; Node suite is green. I also treated empty-search feedback as Important for the new search flow: a completed empty response must be distinguishable from an unsubmitted query. A pure Dart test reproduced the missing status before the state/UI fix.

Ruling: proceed inline using the user’s direct instruction to start the previously agreed second milestone, without repeating the prior design/plan approval loop. Cost if wrong: scope may need adjustment; changes remain isolated and unmerged.
Ruling: regional discovery uses actual Kroger locations rather than a invented statewide chain index. Walmart/Amazon adapters remain unavailable pending granted API access. Cost if wrong: broader chain discovery and cross-retailer comparison are unavailable in this version.
Ruling: ambiguous package/multipack quantities stay unknown rather than guessing totals. Cost if wrong: some valid offers have no unit-price rank until quantity parsing is extended.
Ruling: retain private account preferences and local demo preferences as separate stores, without automatic upload. Cost if wrong: users must enter their ZIP again after sign-in.
Ruling: no new hosted project, migration deployment, retailer secret, billing account, Google Play upload or purchase. Live acceptance remains postponed.

## Manual acceptance
Configure Supabase migration/function and Kroger credentials using docs/regional-shopping-setup.md. Verify hosted account privacy with two accounts, ZIP 40165 discovery, actual provider prices, offline errors/retry and Android system keyboard/fold transitions. Future Play uploads require release signing and account setup.

## Final review fixes

- Malformed product variants no longer poison valid variants: `malformed product items do not hide valid package variants` RED→GREEN; Node suite 14/14.
- Malformed optional location fields normalize to strings: `malformed optional location strings retain a usable typed store` RED→GREEN; Node suite 14/14.
- Empty searches have explicit completion feedback: `completed empty search identified` RED→GREEN; standalone regional checks 16/16 and widget regression green.
- Small large-text dropdown and fold-region header regressions RED→GREEN; Flutter suite 86/86. No deferred reviewer findings remain.
