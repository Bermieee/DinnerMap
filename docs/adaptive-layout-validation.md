# Adaptive layout validation

## Automated evidence

Code commit `44ef29607947c2c7f0f49600d0a875c22813db40` (local `f3fcbc0`) was validated by [CI 38008530976](https://github.com/Bermieee/DinnerMap/actions/runs/38008530976).

- 72 Flutter tests passed, including eight window sizes at normal and doubled text size, separating horizontal/vertical hinges, dynamic editor folding, safe insets, keyboard resizing, retained tab state, offline browsing and account-context invalidation.
- Formatting and analysis passed. Analysis reported 89 informational lints; no warnings or errors.
- 41 standalone Dart checks passed: 28 domain/storage/account/shared checks and 13 layout geometry checks.
- 47 PostgreSQL security and shared-storage checks passed.
- Web build passed. Android build status and final versioned run will be recorded after completion.

RED evidence: CI 38007153833 failed 24 new behavior checks before implementation. Subsequent runs caught padded pane minima, dynamic dialog folding and small-screen load-error overflow before their fixes passed in the run above.

## Remaining manual checks

Live checks remain deferred; automated dimensions do not establish physical device behavior.

- Test phone portrait/landscape, tablet and Z Flip/Z Fold transitions, including system keyboard while editing. Verify draft contents and Save/Cancel reachability.
- Test real safe areas, accessibility text sizes, touch targets and screen reader labels.
- Verify printing, file exports and platform share dialogs on Android.
- Configure an authorized Supabase project and test two accounts, Auth redirects/email, Realtime, offline reconnect and conflicts. CI artifacts have no backend configuration.

No retailer credentials, live prices, hosted deployment or database migration were added in this milestone. Account ZIP/region discovery and retailer integration remain milestone 2.
