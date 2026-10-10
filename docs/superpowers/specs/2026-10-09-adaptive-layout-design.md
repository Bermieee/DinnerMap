# DinnerMap adaptive layouts

Status: approved for implementation October 9, 2026.

## Intent and milestones

DinnerMap must remain usable on different phones, tablets, larger windows, and Samsung Z Flip/Z Fold configurations. Users must retain their current work when available space changes. Live device and hosted household testing is postponed until October 10, 2026, America/New_York; that date is not an automated reminder.

Milestone 1 implements adaptive layouts. Milestone 2 adds account ZIP profiles, regional store discovery, and retailer price comparison. Milestone 2 gets its own specification and implementation plan after milestone 1. No retailer credentials, external projects, billing, or database migrations are introduced by milestone 1.

## Approach

Use available Flutter layout constraints and display features rather than device names or physical pixel dimensions. Retain existing Material styling and planner/account controllers. Introduce a small shared layout policy and reusable constrained page/dialog containers; extract calendar and selected-day sections where necessary. This avoids duplicating mobile and tablet screens with independent state. Maintaining separate device-specific screens would multiply state and testing; merely enlarging the existing single column would waste tablet space and leave hinge problems unresolved.

## Window policy

All dimensions below are logical pixels measured after safe insets and navigation allocation. Bottom navigation is used below 600 pixels of usable shell width; a rail is used at or above 600 when there is sufficient height for its destinations. Short landscape windows fall back to bottom navigation if the rail would overflow. Page content is centered and capped at 1440 pixels.

Calendar content remains stacked unless it can allocate at least 560 pixels to the calendar, 320 to the detail panel, and 24 to the gap. At that threshold it uses two panes. Recipe cards use a grid with a minimum card width of 280 pixels; shopping and household forms use readable constrained columns rather than stretching controls across a large screen. Narrow controls wrap and long text remains readable without horizontal page scrolling.

Calendar cells show the date and a shortened meal label in compact mode, with the full meal name in the selected-day detail and accessible semantics. Touch targets remain at least 48 pixels where actionable; extremely narrow windows use an accessible day list when a seven-column calendar cannot provide adequate targets. Do not shrink text to fit. Larger text can trigger stacked content even in otherwise wide windows.

## Foldables and insets

Account for reported hinges, folds, safe areas, and keyboard insets. A separating vertical display feature can split calendar and detail only when both resulting regions meet their minimum widths. Otherwise place the stacked interactive content within the largest usable region. A separating horizontal feature uses the largest usable region for the stacked page; no tabletop-only feature is added. Non-separating creases do not force a split. No interactive control or dialog spans an obstructing hinge.

Folded cover displays and unfolded screens follow the same constraints. The closed Z Flip exterior display is supported only when Android actually permits launching the app there; launcher eligibility and hardware-specific behavior require device testing and are not promised by widget tests.

## State and interactions

Changing width, orientation, or display features preserves the active tab, calendar month/date, recipe search, shopping start/weeks/unit, and text in an open editor. Stable page identities and controllers survive layout changes; restructuring a row into a column must not recreate editor state. Preserve page scroll position when switching tabs using stable storage keys or retained page state. Account switches still clear household-specific data as designed; layout state must not leak edits between accounts.

Dialogs fit the usable region, use scrollable content, and keep cancel/save actions reachable with a keyboard open. Recipe picker and recipe editor retain draft text during resizing. Banners and shell actions wrap or scroll on short screens, leaving main content reachable.

Replace the existing whole-page offline pointer block with mutation-level disabling where the adaptive work touches screens. Shared offline users can scroll, search, select dates, and read recipe details. Shared writes, undo, shuffle, generation, editing, and checkoffs remain unavailable until the controller permits them. Date/week/unit selections may change locally without sending writes. Existing conflict and pending-operation protections remain authoritative.

## Verification and acceptance

Widget coverage includes 320×568, 390×844, 360×780, 600×960, 800×1280, 1280×800, and 1440×900 windows, plus short landscape 844×390. These are representative logical windows, not exact Samsung hardware specifications. Test vertical and horizontal obstructing hinges, a non-separating fold, text scale 2.0, safe insets, and keyboard insets. Assert no layout exceptions and that important controls can be reached by scrolling.

Interaction tests resize an existing mounted app while preserving selected date, tab, recipe search, shopping options, and an open editor draft. Verify that offline browsing remains usable and mutation controls do not call shared writes. Preserve existing household conflict regression coverage and grocery calculations.

Run project formatting, analysis, Flutter tests, pure Dart checks, database regression checks, and Android/web builds through the established CI path. Automated results must be distinguished from device testing. Physical folding transitions, cover-screen launch, keyboard behavior, printing/sharing, and hosted two-account collaboration remain manual acceptance items for the resumed live test session.

## Milestone 2 boundary

The agreed next scope saves a five-digit US ZIP per account and resolves region metadata. Store discovery is based on actual nearby locations and user selection, not assumed chain popularity from a state. ZIP 40165 is the user's example; it is not silently assigned to every account. Initial proposed discovery radius is 25 miles, user-adjustable. Household meal/list data stays shared while account location preferences remain personal; a later explicit household default can be designed if needed.

Use server-side retailer adapters to keep provider secrets outside APK/web bundles. Start with Kroger ZIP-based location lookup and location-specific product search/prices. Establish Walmart grocery access before activating its adapter. Prepare Amazon comparison integration subject to Associates/Creators API eligibility and permitted usage. Do not substitute seller inventory APIs for consumer grocery pricing or present fixture data as live offers.

Compare equivalent products with package size, unit price, selected store/fulfillment, availability, retrieval time, and unknown-price handling. Show substitutions separately; Amazon multipacks and shipping/membership costs must not silently outrank equivalent local packages. Low/high package-price sorting remains available; unit-price sorting gets an explicit separate control. Live activation requires credentials and applicable retailer terms review.

Official references checked October 9, 2026:

- Kroger locations: https://developer.kroger.com/documentation/api-products/public/locations/tutorial
- Kroger products: https://developer.kroger.com/documentation/api-products/public/products/overview
- Walmart grocery: https://www.walmart.io/docs/opd/stores/grocery-introduction
- Walmart locator: https://walmart.io/docs/opd/quick-start-guide/catalog-store-service-locator
- Amazon prerequisites: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/introduction
- Amazon registration: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/onboarding/register-for-creators-api

These references establish integration direction, not granted access or a deployed price service.
