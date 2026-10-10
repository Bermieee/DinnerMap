# Adaptive Layouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make existing DinnerMap flows usable across phone, tablet, landscape, and foldable windows while preserving current work.

**Architecture:** A shared constraint/display-feature policy supplies usable regions and navigation decisions. Existing stateful pages remain mounted across navigation and resizing; focused calendar components provide stacked and two-pane arrangements without separate controllers. Mutation-level permissions replace the global offline pointer block.

**Tech Stack:** Existing Flutter 3.47.7, Dart language version 3.8, Material 3, Riverpod, Flutter widget tests, existing GitHub CI. No new product dependencies.

**Spec:** `docs/superpowers/specs/2026-10-09-adaptive-layout-design.md` (approved October 9, 2026).

## Global Constraints

- Dimensions are logical pixels after safe insets and navigation allocation.
- Bottom navigation below 600 usable shell pixels; rail at or above 600 only when height permits.
- Page width cap 1440; calendar/detail minimum widths 560/320 plus 24 gap.
- Recipe grid minimum card width 280; interactive targets minimum 48.
- No controls or dialogs span an obstructing hinge; large text must not be shrunk to fit.
- No billing, credentials, retailer integration, or schema changes in this milestone.
- Live device/hosted testing remains deferred until October 10, 2026, America/New_York.
- Use isolated feature branch; preserve prior household work and leave a draft PR without merging.
- Local Flutter bootstrap is unavailable following an automatic approval rejection; use established CI for Flutter commands. Safe standalone Dart formatting/checks remain available.

## Review Focus

- Short landscape with keyboard: save/cancel and main content remain reachable (Tasks 1, 4).
- Resizing during an editor draft or switching tabs: draft, selections, and scroll state survive (Tasks 2, 4).
- Asymmetric fold regions and a hinge intersecting navigation: choose usable region without placing actions under it (Tasks 1, 3).
- Offline shared browsing after a conflict: read interactions work while every mutation remains disabled (Task 5).
- Account change with retained pages or an open editor: previous household drafts cannot write into the new account (Tasks 2, 4).

## File responsibilities

- Create `lib/layout/adaptive_layout.dart`: pure layout decisions and usable-region selection.
- Create `lib/layout/adaptive_page.dart`: constrained region-aware page/dialog wrappers.
- Modify `lib/app.dart`: adaptive shell, retained pages, bounded banners, remove global pointer blocking.
- Create `lib/features/planner/planner_calendar.dart`: calendar grid/day-list presentation and selection callbacks.
- Create `lib/features/planner/planner_day_detail.dart`: selected-day presentation and existing guarded commands.
- Modify `lib/features/planner/planner_screen.dart`: owns month/date and composes calendar/detail.
- Modify `lib/features/planner/recipe_screen.dart`: adaptive grid, region-aware picker/editor/detail.
- Modify `lib/features/shopping/shopping_screen.dart` and `lib/features/household/household_screen.dart`: constrained forms, wrapped controls, mutation guards.
- Create tests in `test/layout/` and `docs/adaptive-layout-validation.md` for evidence/manual checklist.

## Task 1: Layout policy and usable regions

**Interfaces:** Produce `AdaptiveLayout.resolve({required Size size, required EdgeInsets padding, required List<DisplayFeature> displayFeatures, required double textScale})`, returning `AdaptiveLayout` with `Rect primaryRegion`, `Rect? secondaryRegion`, `bool useRail`, and `bool canSplitCalendar`. Produce `AdaptivePage({required Widget child, double maxWidth = 1440})` and `AdaptiveDialog({required Widget child})`; both use the policy and remain scroll/keyboard safe. Inputs come from current MediaQuery and LayoutBuilder constraints, not device identifiers.

- [ ] Write `test/layout/adaptive_layout_test.dart`: assert navigation boundary at 599/600, no rail when available height is below 400, calendar split at usable width 904 but not 903, cap at 1440, and stacked fallback at text scale 2.0 when enlarged panel minima do not fit. Define scaled minima as base minima multiplied by `max(1, textScale)`.
- [ ] Add asymmetric vertical hinge, horizontal hinge, non-separating crease, safe-inset, and keyboard tests: chosen regions exclude obstructions; two panes require each region's minimum; largest-region ties choose top/left. Assert `primaryRegion.overlaps(obstructingBounds) == false`.
- [ ] Run `flutter test test/layout/adaptive_layout_test.dart` in isolated CI; expect new assertions to fail or missing symbols before implementation.
- [ ] Implement policy/wrappers. Separating hinges partition regions; a zero-width separating fold partitions at its axis. Translate display bounds into local coordinates. Place navigation inside the selected safe region; only calendar-specific composition uses both regions.
- [ ] Run the same tests in CI; expect all pass. Commit `feat: add adaptive region and layout policy`.

## Task 2: Retained adaptive shell

**Interfaces:** Consume Task 1 policy/wrappers. Existing `PlannerScreen(snapshot:)`, `RecipeScreen(snapshot:)`, `ShoppingScreen(snapshot:)`, and household callbacks remain unchanged. Produce shell behavior retaining page states with keys scoped to active user/household or local mode.

- [ ] Write `test/layout/adaptive_shell_test.dart`: mounted app navigates calendar→recipes→shopping→calendar while preserving month/date, recipe search, shopping start/weeks/unit and scroll offset. Resize 390×844→1280×800→390×844 and assert selected tab/values persist.
- [ ] Add account-context change test: retained old pages are removed and no old draft callback changes new household data. Add short-window banner test asserting main content can still be scrolled into view.
- [ ] Run new tests in isolated CI and confirm failures.
- [ ] Replace switch-created pages with a context-keyed retained page stack. Use stable PageStorageKeys for page scrolling. Keep load/error and household fallback accessible. Apply region-aware rail/bottom navigation and a bounded scrollable status area instead of allowing banners to consume all body height.
- [ ] Run shell tests and existing household screen tests; expect pass. Commit `feat: retain page state in adaptive shell`.

## Task 3: Adaptive calendar and detail

**Interfaces:** Consume `AdaptiveLayout`. Produce `PlannerCalendar({required PlannerSnapshot snapshot, required DateTime month, required DateTime selected, required ValueChanged<DateTime> onSelected, required ValueChanged<DateTime> onMonthChanged})` and `PlannerDayDetail({required PlannerSnapshot snapshot, required DateTime selected})`. Parent retains month/date; detail uses existing planner provider and captured-model guards.

- [ ] Write `test/layout/adaptive_planner_test.dart`: 390-wide stacks sections, 1280-wide shows calendar/detail side by side, narrow usable width below 336 uses day list, seven-column actions have at least 48 logical pixels, full selected meal is readable, and selection survives resize.
- [ ] Add separating hinge tests: adequately wide regions show separate panes; undersized region forces largest-region stacked layout; no actionable element overlaps obstruction. Test text scale 2.0 switches to stacked layout where required.
- [ ] Run tests in CI and observe failures.
- [ ] Extract calendar/detail and compose with LayoutBuilder without recreating month/date state. Use `Semantics` for complete day/meal/cooked labels and shortened visual labels; use day-list fallback below 7×48 usable width. Keep shuffle/undo controls with selected-day detail and preserve existing command semantics.
- [ ] Run planner layout tests and planner/shared regression tests; expect pass. Commit `feat: adapt calendar and meal details to available space`.

## Task 4: Adaptive recipes, shopping, household, and dialogs

**Interfaces:** Consume `AdaptivePage`/`AdaptiveDialog`; keep public screen and `chooseRecipe`, `editRecipe`, `showRecipe`, and `promptText` signatures unchanged.

- [ ] Write `test/layout/adaptive_forms_test.dart`: recipe grid cards at least 280 wide when width permits; shopping controls wrap; household form remains readable and constrained. At 320×568 and 844×390 with keyboard inset 250, open picker/editor and scroll to Save/Cancel without layout exceptions.
- [ ] Add editor-resize test entering a draft then resizing with an obstructing hinge; text remains intact and actions reachable. Reuse/extend existing remote-edit regression to assert account change closes or invalidates old draft saving.
- [ ] Run new tests in CI and confirm failure.
- [ ] Convert recipe results to responsive grid while retaining search/favorite behavior. Constrain shopping/household form width to 800 and wrap action rows. Apply dialog region/keyboard wrappers to picker, editor, detail, text prompts, invitation/import/conflict dialogs; retain text controllers outside layout branches. Avoid introducing writes on resize.
- [ ] Run form tests and existing recipe/household/shopping tests; expect pass. Commit `feat: adapt forms and editors for small and large windows`.

## Task 5: Read-only shared browsing

**Interfaces:** Consume existing `PlannerController.canEdit` and shared pending/conflict guards. No repository or transport interfaces change.

- [ ] Write `test/layout/offline_browsing_test.dart` using existing shared-controller fake: offline/conflicted app can scroll, change selected date, search recipes, read details, choose local shopping options, and export saved data. Assert shuffle, undo, recipe changes/favorites/avoids, notes/servings/cooked, generate, weights, checkoffs, and manual add/remove cannot send a mutation.
- [ ] Run tests in CI and observe current whole-page pointer blocking failure.
- [ ] Remove shell `AbsorbPointer`; apply nullable callbacks/enabled states to each mutation control based on `canEdit`. Re-check mounted/context/controller permission after asynchronous dialogs before invoking mutations. Keep read controls enabled and retain pending/conflict review protections.
- [ ] Run offline browsing and all sync regression tests; expect pass. Commit `fix: allow shared browsing while edits are unavailable`.

## Task 6: Complete matrix, review, and delivery

**Interfaces:** Existing workflow `.github/workflows/flutter.yml` runs the added tests automatically; no test bypass or provider credentials needed.

- [ ] Write `test/layout/adaptive_matrix_test.dart` traversing all four pages at 320×568, 390×844, 360×780, 600×960, 800×1280, 1280×800, 1440×900, and 844×390; include safe insets, text scale 2.0, folds/hinges and keyboard cases. Assert no Flutter exceptions and key controls reachable, using scroll-to-control checks rather than screenshots alone.
- [ ] Run matrix tests; correct uncovered layout failures and rerun affected tests.
- [ ] Run standalone `dart format --language-version=3.8 lib test tool`; publish isolated draft PR targeting `feat/household-sharing` through existing GitHub connector path. CI must pass formatting, `flutter analyze --no-fatal-infos`, all Flutter tests, four pure Dart checks, PostgreSQL regressions, web build and debug APK build.
- [ ] Obtain one fresh whole-branch review through the execution workflow, address actionable findings, then rerun affected checks and final CI for changed product code.
- [ ] Write `docs/adaptive-layout-validation.md` with exact commit/run IDs, counts, build evidence and remaining physical/hosted checks. Update README/version to 0.3.0+3. Commit documentation and leave PR draft; do not merge or claim physical folding/hosted collaboration tested.

## Execution and handoff

Recommended method: native implementation in this session followed by one fresh whole-branch review. Tasks share layout interfaces and existing page state; keeping one implementer reduces coordination while preserving independent final review. Milestone 2 is intentionally excluded from product changes in this plan.

Before execution, use the isolation skill to create a clean feature checkout based on the current household-sharing work, preserving these approved documents. Record task progress in the execution ledger. Remote branches may have connector-created commit histories different from local commits; use the established connector publication path rather than force-pushing local history.
