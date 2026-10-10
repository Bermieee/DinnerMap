# Regional shopping validation

## Scope
Private account ZIP/radius preferences, ZIP metadata resolution/cache, Kroger location discovery and selected-store product search. Local device ZIP saving is available without a backend. Walmart and Amazon are explicitly unavailable. No deployed backend or retailer credentials have been configured.

## Evidence underway
- Local pure Dart regional checks: 16 passing (ZIP validation/leading zeroes, radius, price sorts/unit families, persistence and disposed-context response).
- Local region PostgreSQL fixtures: 13 passing, alongside 44 existing fixture checks. Hosted PostgreSQL CI adds existing concurrency checks.
- Node retailer/handler tests: 14 passing, including provider normalization, safe errors/token renewal, auth verification, throttling, bounded request bodies and optional cache failure recovery.
- RED CI 38020890591: 79 existing Flutter tests passed; two new regional screen tests failed because the new controls had not been implemented. Analysis/formatting and database job passed.
- CI 38021665347 passed 84 Flutter tests, including discovery, store selection, product search, empty results and landscape/tablet large text. Two layout regressions reproduced narrow large-text overflow and a header outside the largest fold region; fixes are under verification.
- Full implementation CI is running. No success claim for complete Flutter suite/builds yet.

## Review and decisions
Independent review found no Critical findings. I regraded the two malformed-provider response findings as Important because one corrupt row could hide valid store/product results. Tests reproduced both failures before filtering malformed items and normalizing optional store fields; Node suite is green. I also treated empty-search feedback as Important for the new search flow: a completed empty response must be distinguishable from an unsubmitted query. A pure Dart test reproduced the missing status before the state/UI fix.

Ruling: proceed inline using the user’s direct instruction to start the previously agreed second milestone, without repeating the prior design/plan approval loop. Cost if wrong: scope may need adjustment; changes remain isolated and unmerged.
Ruling: regional discovery uses actual Kroger locations rather than a invented statewide chain index. Walmart/Amazon adapters remain unavailable pending granted API access. Cost if wrong: broader chain discovery and cross-retailer comparison are unavailable in this version.
Ruling: ambiguous package/multipack quantities stay unknown rather than guessing totals. Cost if wrong: some valid offers have no unit-price rank until quantity parsing is extended.
Ruling: retain private account preferences and local demo preferences as separate stores, without automatic upload. Cost if wrong: users must enter their ZIP again after sign-in.
Ruling: no new hosted project, migration deployment, retailer secret, billing account, Google Play upload or purchase. Live acceptance remains postponed.

## Manual acceptance
Configure Supabase migration/function and Kroger credentials using docs/regional-shopping-setup.md. Verify hosted account privacy with two accounts, ZIP 40165 discovery, actual provider prices, offline errors/retry and Android system keyboard/fold transitions. Future Play uploads require release signing and account setup.
