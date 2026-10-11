# Regional shopping validation

## Scope
Private account ZIP/radius preferences, ZIP metadata resolution/cache, Kroger location discovery and selected-store product search. Local device ZIP saving is available without a backend. Walmart and Amazon are explicitly unavailable. The existing Supabase backend is deployed; Kroger credentials are configured and initial live discovery/pricing was confirmed by the user.

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

## Grocery-list pricing milestone — 0.5.0+8

Source commit `bf58141097e4b0880f29769421944cb40dbd1ed7` (local `763a9f2`) adds reviewed Kroger product selections and partial grocery-list package estimates. Sixteen pricing checks pass natively and the pricing calculation suite also compiles/runs as JavaScript. Fifteen Node retailer/handler tests pass, including `sold_by` preservation for fixed-unit, variable-weight and unknown price bases. Regional checks pass after restricting calculated unit prices to declared fixed packages.

Independent review identified hidden selections returning after grocery quantities reverted. The fix permanently removes changed/removed row selections, clears stale-list estimates, invalidates pending picker results on list/profile changes and keys the panel by planner and regional repository identity. A 5→7→5 quantity regression verifies the old quote stays discarded. Follow-up review found no remaining Important issues.

Supabase retailers function version 2 deployed ACTIVE with JWT verification retained. An unauthenticated deployed POST returned HTTP 401. No database migration was needed. Real Kroger product/price acceptance remains blocked on developer application registration and `KROGER_CLIENT_ID` / `KROGER_CLIENT_SECRET` configuration. No cart/checkout or purchase action was performed.

[CI 38091890843](https://github.com/Bermieee/DinnerMap/actions/runs/38091890843) passed formatting, analysis (no warning/error), 97 Flutter tests, all standalone native/JavaScript checks, PostgreSQL checks, 15 Node retailer tests and Deno function type checking. The configured web build passed; artifact 11684477017 has ZIP SHA-256 `d6a784c30ac75a072834a58bd91129d22125385319cb99a248de6c9e47d5849b`. Digest, 108 starter recipes, public Supabase config and new pricing strings verified before packaging. Android build verification is still running at this checkpoint.

The web source was packaged from Sites commit `fe24363628f9806a58e874d03bf18eef49c823cd`; only HTML/manifest metadata differs from the compiled CI assets. Managed interactive browser QA was unavailable; no live Kroger provider acceptance is claimed.

DinnerMap0.5.0 published successfully at https://dinnermap-web.lushsnail1.chatgpt.site with audience preserved. Deployment `appgdep_6acabe4cfb048191abc0363a0eaa3c1b`, version `appgprj_6aca85cdb0208191af6166428b56d663~appgver_dc61993d5da08191ac6c4dae1f1c7fae`.

## Consumer grocery model — 0.5.1+9

Source `37765ef5b05ac37491228b89ea7b185a5d9192e3` (local `11ad101`) replaces raw internal ml display with shared cooking-unit formatting. A RED native check reproduced 78.8627455 ml flour displaying as ml; after implementation it shows 1/3 cup and a reviewed 5 lb fixed flour bag suggests one package. Thirteen consumer checks cover fractions, retained cooking weights/instructions, density variants, exports, whole eggs/cartons, rounding noise and upward loose shopping weights. Native and compiled JavaScript checks passed locally before CI.

Reviewed products now survive closing the estimate screen and appear in the grocery list and exports during the app session. Scope remains personal and in-memory; app reloads clear quotes. Independent review caught a pending piece-weight dialog returning an old package count after a shared estimate update. The result-generation guard now invalidates on piece-weight changes; a Flutter regression covers 18 pieces at 6→12 ounces while the dialog remains open. Follow-up review found no Important issues.

User live acceptance on 2026-10-10: Kroger credentials were configured, initial secret-name mismatch corrected, and nearby store lookup/selection succeeded. User then reported the integration working before raising consumer-quantity feedback. No secrets were recorded in source or documentation. Full two-account regional privacy and physical-device purchase-flow acceptance remain pending.

[CI 38093771564](https://github.com/Bermieee/DinnerMap/actions/runs/38093771564) passed formatting, analysis, 102 Flutter tests, native/compiled-JavaScript consumer and pricing checks, PostgreSQL, Node retailer tests and Deno checking. The catalogue regression covers all 108 starter recipes; phone/desktop shopping screens and exported reviewed choices pass. Web artifact 11685710251 ZIP SHA256 `d69ec01097646ddcdf9c05e41492a2b410eca5e09b06e1ab3197b2cbafd92dae` verified before extraction. Android CI remains in progress at this documentation checkpoint.

Published successfully at https://dinnermap-web.lushsnail1.chatgpt.site from Sites source `b6b38152b899b75a9921051117e0fa03c41507b2`. Deployment `appgdep_6acac5889f188191b676bb8f052de8a1`, version `appgprj_6aca85cdb0208191af6166428b56d663~appgver_b2f09dc4f6b48191963c596d252541b6`. Audience preserved. Original compiled assets unchanged; HTML/manifest metadata adjusted. Interactive live browser QA was unavailable. No backend or database changes were needed.

## Recipe-to-store search cleanup — 0.5.2+10

Source `506f0b53054ef10e2e3fbc67eed3839f6b736708` removes recipe preparation terms from the suggested Kroger query while preserving the original recipe/list identity and editable search. “Boneless chicken breasts, cubed” searches “boneless chicken breasts.” Recognized packaged forms and product descriptors remain. Twenty-two ingredient-name cases pass natively and as compiled JavaScript. Testing the old name-as-query behavior reproduces the chicken mismatch. The widget regression verifies the cleaned query reaches the repository, the original title remains and edited queries are sent as typed. Initial CI exposed a test URI import mismatch; consistent package imports fixed compilation.

[CI 38095783094](https://github.com/Bermieee/DinnerMap/actions/runs/38095783094) passed formatting, analyzer, all104 Flutter tests, existing native/browser checks, PostgreSQL and Node/Deno checks. Web artifact11685778706 ZIP SHA256 `2a76285586eb2118eb4fc8f65f2213e322218e72aea2b6385801d9380d6e5ab8` verified; all108 recipe assets, Supabase public configuration and compiled cleanup strings verified. Android build remains in progress at this checkpoint.

Published successfully at https://dinnermap-web.lushsnail1.chatgpt.site. Sites source `e9e48f833d504d3035acf67989f647e176e80a56`, deployment `appgdep_6acacda5ff2081919433ca47a56937c8`, version `appgprj_6aca85cdb0208191af6166428b56d663~appgver_ced8a3b4779481919c4972dc2de8c141`. Audience preserved. Only HTML/manifest metadata differs from compiled CI output. Live interactive browser QA and real-provider search acceptance for the new suggestions remain pending; no backend or database changes required.

## Whole-list deal suggestions — 0.6.0+11

Source `d47cc7ed6658b74b731ff4c129ac22b2a07632a8` (local `3f96540`) adds **Find best deals at Kroger** to the existing list estimate screen. It searches unpriced rows using cleaned queries, sequentially paced at2200ms between requests; stages lowest sufficient whole-package line-cost suggestions; and requires explicit individual or bulk review before adding quotes. Existing reviewed choices remain. Unknown prices/quantities, variable-weight, wrong-store, unavailable and uncertain-name products remain manual. Progress, stop, per-row failure notes and stale/account/store/list/piece-weight cancellation guards are implemented. The ranking calculation is independent of the Kroger screen and reusable with future vendor adapters; only Kroger is integrated now.

Independent review found shared-word food false positives (butter→peanut/apple butter, butter cookies, chicken dog treats/salad). RED checks reproduced failures; a conservative allowed-extra-word gate now rejects unfamiliar food qualifiers, alongside incompatible-form guards. Legitimate recognized product forms still match. Follow-up review has no remaining Important findings. Nine automatic checks pass natively and as compiled JavaScript, including minimum sufficient total rather than unit price. New widgets cover staged review, preserving accepted choices on repeat search, cancelled search and late results after changed quantities.

[CI 38096525277](https://github.com/Bermieee/DinnerMap/actions/runs/38096525277) passed formatter/analyzer,107 Flutter tests, all native/browser checks, PostgreSQL, Node retailer and Deno checks. Web artifact11685979204 ZIP SHA256 `b645308611da40641eb31b4ef2c34ac846c88fd9d221dbf475c49bbeab926cb3` verified; all108 recipe assets, public Supabase configuration and compiled automatic-search/review controls verified. Android CI remains in progress at this checkpoint.

Published successfully at https://dinnermap-web.lushsnail1.chatgpt.site. Sites source `b298874c53233afd64103b63ab95488589472bfa`, deployment `appgdep_6acad0afde44819198286f6d95093b80`, version `appgprj_6aca85cdb0208191af6166428b56d663~appgver_31e7dffe490481918245935f7782568f`. Audience preserved; compiled assets unchanged except HTML/manifest metadata. Managed interactive browser QA and real whole-list provider acceptance remain pending. No database/backend changes or purchase actions needed. Limitations: up to50 returned offers, no cross-row package allocation, no dietary/allergen certification, session-only quotes.

## Clear grocery list and shopping headings — prepared0.6.1+12

Source `2b1b0fcb8c11d3e323230345b0ab9be2d59ccd3a` (local1093374) adds clearShoppingList and explicit nullable snapshot removal, verified shared clearList commands, quote removal, and preparation-free grocery/pricing/export names. Calendar/recipes and per-piece preferences remain. The shared mutation deletes only current household shopping rows/list after comparing the current list JSON under existing authentication/household lock/idempotency. Changed checkoffs/manual items/generations reject stale clears; conflict reapply is disabled for clear requests until user reload/review. Independent review has no Important findings.

PGlite RED without migration reproduced unsupported clear; all database suites GREEN with migration, including28 shared-storage checks. [CI38098028768](https://github.com/Bermieee/DinnerMap/actions/runs/38098028768) passed108 Flutter tests, formatting/analyzer, native/browser checks, PostgreSQL and Node/Deno. Widget verifies clear persistence, quote removal, cleaned chicken label and retained planner data. Initial full-tree tool output truncation damaged uploaded source; all12 changed blobs were reuploaded individually and compared to local Git blob SHAs before creating the exact full tree.

Configured web artifact11686857450 digest7374a57db2a7e739db1db9637f07fe3ca57025b0691b161cdbc8095f09721c27 verified;108 recipe assets, public config and compiled clear control checked. Managed interactive browser QA unavailable. Android CI was running at checkpoint.

NOT PUBLISHED: Supabase apply_migration failed twice and transactional execute_sql once with `McpServerError: Invalid or expired requestState`. Read-only inspection confirms live private.apply_one has no clearList/conflict guard. No user grocery data was cleared. Migration file supabase/migrations/20261011001500_clear_shopping_list.sql is ready for the project SQL editor. Apply it, verify function support, then publish prepared archive `/workspace/sites/dinnermap-web-0.6.1-deploy.tar.gz`. Existing live0.6.0 remains.

### Clear-list deployment completed

User applied the supplied SQL update on2026-10-10(local). Read-only live function verification confirms clearList support and changed-list conflict guard. Prepared0.6.1 published successfully from Sites source `d1ff362b04b737124debd6f7a4ce663729d0eeec`, deployment `appgdep_6acadd896020819193036d4d7b9d8359`, version `appgprj_6aca85cdb0208191af6166428b56d663~appgver_fe0c8023c4f481918c3dc3e15f8f73a8` at https://dinnermap-web.lushsnail1.chatgpt.site/. Earlier backend blocker is resolved. Audience preserved. No actual user list was cleared by the assistant; button/device acceptance remains for the user.


## 0.6.2 ingredient matching audit (2026-10-11 UTC)

User reported flour request failure and rejected barbecue sauce, black pepper, and boneless chicken. A native executable reproduction rejected legitimate chicken because generic trailing-s removal corrupted `boneless` and `skinless`; it also rejected BBQ alias and ground pepper and could not convert pepper spoon quantities to package mass. New regression checks failed before the corresponding fixes and now pass.

`tool/catalog_audit.dart` audits all 108 bundled recipes, 607 distinct ingredient names and 1,430 ingredient lines into `docs/ingredient-search-audit.csv`. It checks nonempty searches, identity matches, quantity/unit limitations, alternative/combined ingredients, and every curated recipe guide against the actual starter loader. This is a complete static catalog audit, not a live store-inventory sweep or a guarantee of supplier availability.

Known plurals and aliases replace indiscriminate suffix stripping; cooking-use suffixes no longer pollute searches. Preserve food-form guards, explicit recipe alternatives, and user confirmation. Ground black pepper uses USDA SR28's 2.3 g/tsp estimate; plain barbecue sauce uses Health Canada's 16 g/15 ml estimate. These are approximate shopping conversions; recipes keep their cooking quantities, and suggestions still need review. Unknown ingredient densities remain manual. Quarts/pints/gallons and saved optional units work during calculation without rewriting starter records or curated dietary guide signatures. Optional cooking labels remain visible.

Every rejected row now distinguishes empty results, mismatched names, missing price, unavailable stock, variable weight, unknown package basis/size and incompatible quantities. Request failures retain the backend's reason; a temporary service failure gets one paced retry. Authentication/configuration/quota errors do not retry. Changed account/store/list or cancellation prevents accepting a late result.

Native matching, automatic, consumer, pricing, domain and discovery checks passed; matching checks also compiled and passed in JavaScript. Review found and resolved curated-guide and optional-display regressions. Full CI/build/publication evidence follows after completion. No backend schema or secret changes required.

Retailer-name checks also use Kroger's public product names for Original Classic BBQ Sauce (0001111015424), boneless skinless breast chunks with rib meat (0001111096912), and flour (0001111085402). Published names are evidence for matcher vocabulary, not current inventory, store price, or actual API responses.
