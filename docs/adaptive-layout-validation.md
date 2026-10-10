# Adaptive layout validation

## Automated evidence

Version **0.3.0+3**, code commit `6b63aa02554abab0071252291332971c56e0c3cb` (local `f335fd2`), passed [CI 38009787770](https://github.com/Bermieee/DinnerMap/actions/runs/38009787770) on October 10, 2026 UTC. Subsequent evidence commits change documentation only.

- 79 Flutter tests passed, including eight window sizes at normal and doubled text size, separating horizontal/vertical hinges, dynamic editor folding, safe insets, keyboard resizing, retained tab state, offline browsing, semantics activation and account-context invalidation.
- Formatting and analysis passed. Analysis reported 92 informational lints; no warnings or errors.
- 41 standalone Dart checks passed: 28 domain/storage/account/shared checks and 13 layout geometry checks.
- 47 PostgreSQL security and shared-storage checks passed.
- Web and debug Android APK builds passed.
- [Android artifact](https://github.com/Bermieee/DinnerMap/actions/runs/38009787770/artifacts/11653048160): archive contains `app-debug.apk`; SHA-256 of artifact archive `b10ff38e70a0e9680b268742a65deff332e4ef2efc6d049cce75cdb2c22615e1`.
- [Web artifact](https://github.com/Bermieee/DinnerMap/actions/runs/38009787770/artifacts/11652609143): SHA-256 of archive `bf42eeee424e748f1202e2ed6eea321a35ff793b7a90b54c2b5d2b97704d06f7`.

Artifact downloads require GitHub access. Default artifacts run in local mode without Supabase project configuration. PR3 remains draft and targets `feat/household-sharing`; neither branch was merged.

RED evidence: CI 38007153833 failed 24 new behavior checks before implementation. Subsequent runs caught padded pane minima, dynamic dialog folding and small-screen load-error overflow before their fixes passed in the run above.

## Remaining manual checks

Live checks remain deferred; automated dimensions do not establish physical device behavior.

- Test phone portrait/landscape, tablet and Z Flip/Z Fold transitions, including system keyboard while editing. Verify draft contents and Save/Cancel reachability.
- Test real safe areas, accessibility text sizes, touch targets and screen reader labels.
- Verify printing, file exports and platform share dialogs on Android.
- Configure an authorized Supabase project and test two accounts, Auth redirects/email, Realtime, offline reconnect and conflicts. CI artifacts have no backend configuration.

No retailer credentials, live prices, hosted deployment or database migration were added in this milestone. Account ZIP/region discovery and retailer integration remain milestone 2.

## Implementation decisions

- Ruling: use clean dedicated checkout on new feature branch — approved native isolation — cost: same checkout instead of second worktree.
- Ruling: group initial failing tests into isolated CI run because local Flutter bootstrap is unavailable — RED still precedes implementation — cost: test attribution uses individual named tests.
- Ruling: rail minimum height 400 and split minima scale with text scale — explicit plan values — cost: short tablet uses bottom navigation.
- Ruling: factor numeric geometry into window_layout.dart beneath Flutter bridge — enables safe local validation without blocked Flutter bootstrap — cost: an extra small file, bridge still verified in CI.
- Ruling: reopen draft PR to trigger CI after synchronize event produced no run — reversible metadata action on own draft — cost: extra closed/reopened event in PR history.
- Ruling: all subsequent publications explicitly enumerate full tracked tree — avoids relying on connector base-tree behavior — cost: slightly larger metadata payload.
- Task 3: Ruling: include grid spacing in day-list threshold (366 rather than bare 336) — actual seven 48-pixel targets require six 5-pixel gaps — cost: some narrow phones use day list.
- Task 3: Ruling: optional month argument on day detail — shuffle month must preserve displayed month independent of selected date — cost: small interface extension.
- Task 4: Ruling: recipe detail uses scrollable adaptive dialog instead of draggable sheet — same reading/actions with shared hinge/keyboard behavior — cost: sheet drag affordance removed.
- Task 4: Ruling: use focused PopupRoute with closed-loop focus traversal — Flutter RawDialogRoute preselects left sub-screen before our policy sees features — cost: maintain a small route wrapper to preserve live largest-region behavior.
- Ruling: task-done verifies captured isolated CI logs for Tasks 1–5 rather than blocked local Flutter execution — actual full-suite CI output was fetched and read — cost: verification depends on pinned remote run identity.
- Final: Ruling: reviewer excluded final version/README/evidence completeness — finish these as Task 6 before delivery — cost: no second reviewer on documentation.
- Final: Ruling: physical folding/platform keyboard/printing/sharing/hosted collaboration remain unverified — preserve explicit manual acceptance rather than treating simulated dimensions as devices — cost: device-specific problems may remain until live testing.
- Final: Ruling: retailer/location work stays outside this layout branch — milestone 2 remains separately scoped — cost: no live price cross-check in this APK.
- Final: Ruling: superseded Android run cannot count as a successful build — require a completed final versioned run — cost: additional CI build time.
- Ruling: collapse app bar and use a 48-pixel icon-only navigation bar below 240 usable height — reserves content above a landscape keyboard while keeping tab controls — cost: header/labels return only after usable height grows.
- Task 6: Ruling: preserve already-agreed draft PR and branch rather than ask the finishing menu again — user approved draft delivery without merge — cost: work remains unmerged for integration review.
- Task 6: Ruling: final evidence commit changes documentation only — validated runtime remains exactly the versioned artifact commit — cost: automatic PR CI may rerun on documentation; cited build is the completed code run.

Independent whole-branch review identified five Important findings and no Critical or deferred Minor findings. Seven regression tests reproduced every finding in CI38009086435 (72 passed, 7 failed) before fixes: landscape keyboard reachability, screen-reader date activation, largest fold region, offline conflict preservation, and expired Import/Leave/Date confirmations. All seven review regressions passed in CI38009787770, with the full Flutter suite79/79, Dart41/41, PostgreSQL47/47 and both builds green. No deferred minor findings remain.

## Final review fixes

- Final: fixed short-keyboard content — offline main content stays reachable above landscape keyboard RED→GREEN; Flutter suite79/79.
- Final: fixed calendar semantic activation — calendar days expose screen reader activation RED→GREEN; Flutter suite79/79.
- Final: fixed smaller fold pane — single page uses larger asymmetric fold region RED→GREEN; Flutter suite79/79.
- Final: fixed offline conflict loss — offline conflict reapply preserves proposed edit RED→GREEN; Flutter suite79/79.
- Final: fixed expired account dialog intent — old Import/Leave/Date dialog cannot act after account replacement RED→GREEN; Flutter suite79/79.
