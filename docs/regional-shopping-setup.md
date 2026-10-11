# Regional shopping setup

DinnerMap 0.4 saves a five-digit US ZIP and search radius, separately from shared household meal plans. Open Household → Stores & prices. Local builds store these preferences only on the device; verified accounts use their own Supabase profile. Local ZIPs are not automatically uploaded when you sign in.

## Enable live Kroger discovery

1. Complete docs/household-setup.md for the existing Supabase account backend.
2. Apply supabase/migrations/202610100001_region.sql after the existing migrations. It adds private account location profiles, a read-only ZIP metadata cache, and a 30-request-per-minute per-account limiter.
3. Create your Kroger developer application with the public Locations and Products APIs. Obtain client credentials on the Kroger developer portal. Keep the secret in backend configuration only.
4. Deploy supabase/functions/retailers with the Supabase CLI after setting KROGER_CLIENT_ID and KROGER_CLIENT_SECRET using Supabase project secrets. The function uses the existing SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY provided to deployed functions. Retain JWT verification; the handler also checks the user and verified email server-side.
5. Build with your SUPABASE_URL and SUPABASE_ANON_KEY as described in the household guide. Sign in, verify the email, save ZIP/radius and use Find nearby stores. Select a returned location, then search a product.

The DinnerMap test project now has all three schemas installed, shared-table Realtime enabled, and the authenticated retailers function deployed. CI uses config/dinnermap-test.json, containing only the public project URL and publishable client key. The user configured Kroger credentials on 2026-10-10 and confirmed store discovery/selection and product pricing in the web app. No Google Play upload is performed.

## Behavior and limitations

ZIP resolution uses https://api.zippopotam.us/us/{zip}; positive results are cached for 30 days. Kroger discovery returns up to 50 locations and product search up to 50 products, preserving each returned item variant. Empty results are not evidence that no other chains serve the area. Walmart and Amazon are marked access pending and do not return offers. Account ZIP values are sent to the ZIP resolver and Kroger when requested; product search terms and selected locations are sent to Kroger. Account preferences remain personal even when family members share a planner.

Price sorting supports low/high package prices and low/high normalized unit prices. Compare weight per pound, volume per fluid ounce, or count per item explicitly; results with incompatible units appear after comparable results. Missing or ambiguous quantities and unconfirmed or variable-weight sale bases never become calculated package-derived unit prices. Multipacks with ambiguous sizes retain the provider’s original size. Kroger promo=0 is treated as no promotion; regular=0 is a known zero price. Prices exclude tax and are not checkout totals. Reported stock level is displayed without claiming guaranteed fulfillment availability.

Product selection remains user-reviewed. Grocery-list package estimates are available in 0.5.0; automatic product matching, broader retailer comparison, carts and purchases remain future work.

## Acceptance still required

Household login and sharing have been tested on the web and a physical foldable. The regional migration is applied and retailers function version 2 is deployed. Initial live store discovery and pricing were confirmed by the user. Two-account regional profile isolation and physical-device retailer acceptance remain pending. Offline behavior shows an error while preserving saved ZIP preferences; store results are session-only. Google Play testing and physical foldables remain deferred.

## Reviewed grocery-list estimates (0.5.0)

Generate a shopping list, then choose **Price this list at Kroger**. Select a store, search for a product for each grocery item, review the package size, and confirm the number of packages. Compatible known fixed-package quantities suggest a rounded-up package count. Unknown sizes or units require a manual count; unknown price basis also requires explicit fixed-package confirmation. Variable-weight products are displayed but excluded from fixed-package estimates.

The displayed total is partial until every item is priced. Unpriced items are excluded, and an entirely unpriced list shows a dash rather than zero. The estimate includes checked list items and manual items; it excludes tax, delivery fees, coupons and variable-weight checkout adjustments. Store or ingredient quantity changes invalidate selections; a stale shopping list must be regenerated. In 0.5.1, reviewed choices last for the current app session, survive closing the pricing screen and appear on the main grocery list and exports. They are not saved across app reloads or shared between household members.

Initial live store discovery and product pricing were confirmed by the user after configuring credentials. Full two-account/physical-device retailer acceptance remains pending. Register a DinnerMap application at https://developer.kroger.com/ and add `KROGER_CLIENT_ID` and `KROGER_CLIENT_SECRET` under Supabase **Edge Functions → Secrets** for project `cmrfydajyhoctunacdvi`. Do not put the client secret in Flutter/web configuration or GitHub source. Once configured, verify ZIP lookup, selected-store product prices, package sizes and account isolation with real results. No cart or checkout integration is included in this milestone.

## Consumer quantities (0.5.1)

All recipe ingredient displays and grocery outputs use the same readable amount formatter: cups/tablespoons/teaspoons and common fractions for volumes, familiar pounds/ounces for shopping weights, and original mass units for cooking recipes. The exact stored recipe quantities are unchanged. Internal millilitre totals remain precise for calculation and do not leak into the list display.

The main list displays **Buy** recommendations first and **Needed for recipes** beneath. Reviewed store products display whole-package counts and estimated line costs; unselected ingredients show a whole-item or minimum-weight requirement where possible. Select a product using **Price this list at Kroger** to turn compatible requirements into actual package counts. Copy/share/print/TXT/CSV carry the reviewed packages and recipe needs.

Limited ingredient-specific volume-to-weight estimates use the [King Arthur Baking weight chart](https://www.kingarthurbaking.com/learn/ingredient-weight-chart): flour 120 g/cup, granulated sugar 198 g/cup, cornstarch 112 g/cup, butter 226 g/cup, dry long-grain rice 198 g/cup, olive oil 200 g/cup, vegetable oil 198 g/cup and heavy cream 227 g/cup. These are labelled shopping estimates, not rewrites of cooking measurements. Ambiguous ingredients/preparations (including cooked rice or flour blends), incompatible units, unknown can sizes and variable-weight pricing require review instead of invented conversions.

Source quantity and preparation data remain intact, including ranges, optional ingredients and “to taste.” No household recipe migration is required. Store, account, planner context, stale-list, changed-row and piece-weight updates discard or reject outdated quotes, including pending dialogs.

## Recipe preparation and store searches (0.5.2)

Kroger searches start with a shopping product name instead of the entire recipe label. For example, “boneless chicken breasts, cubed” searches “boneless chicken breasts”; “onion, finely chopped” searches “onion.” Cooking directions, optional/garnish notes and parenthesized weights are removed from the suggested search. Meaningful descriptors such as boneless, skinless, ground and frozen remain, along with recognized store forms such as diced tomatoes, minced garlic, shredded cheese and peeled/deveined shrimp. The original recipe/list name and quantities remain unchanged, and the search field is editable. This is a conservative local search suggestion, not automatic product selection or a guarantee of Kroger results.

## Whole-list deal suggestions (0.6.0)

Open **Price this list at Kroger**, choose a store, then **Find best deals at Kroger**. The app searches unpriced rows sequentially, using preparation-free queries and pacing requests below the existing 30/minute account quota. It keeps previously reviewed selections. Each row proposes the lowest sufficient whole-package cost among suitable returned offers with known prices and compatible fixed-package quantities. Variable-weight, unavailable, wrong-store, unfamiliar food qualifiers and unknown-quantity offers are not automatically priced.

Review product names, package sizes and dietary suitability, then use individual suggestions or **Accept reviewed suggestions**. Nothing becomes a reviewed grocery-list selection until you accept it. Unmatched or failed searches remain unpriced and offer manual product search. Progress and **Stop search** are available; completed suggestions can be reviewed after stopping. Store/account/list/piece-weight changes reject outdated results. Quotes remain session-only.

“Best” means the lowest calculated line cost among the selected store’s returned suitable products, not a guarantee over Kroger’s entire catalogue, coupons or checkout. The API returns up to 50 offers per search. Requirements are priced per row, without allocating one package across different rows. Estimates exclude tax, fees, coupons and variable-weight checkout adjustments. Conservative matching can leave valid products for manual review; it does not certify dietary/allergen suitability. Shared deal ranking can be reused by future vendor adapters, but only Kroger is integrated now. No cart or purchase is made.

## Clear a saved list (0.6.1)

Use **Clear grocery list** on the grocery screen to remove generated rows, manual items, checkoffs and reviewed product estimates. Meal plans, recipes and per-piece weight preferences remain. Clearing a household list syncs to its members through the existing verified, locked, idempotent mutation path. If someone changed the list meanwhile, reload and review before clearing it. Regenerating normally preserves manual items/checkoffs; clearing starts fresh.

Grocery and pricing headings and exported item names use the shopping product name, leaving preparation such as “cubed” in the underlying recipe instructions. Old saved rows receive the same display cleanup immediately.


## Matching diagnostics (0.6.2)

Refresh the web app after deployment, open the current grocery list and rerun Find best deals at Kroger. Existing accepted choices remain; unpriced rows are searched again. Review suggestions before accepting them. Unknown amounts, alternative ingredients, combined ingredients, variable-weight products and incompatible package units now state the specific review needed. Temporary service failures retry once; quota, authentication and configuration errors show their reason. Manual search remains available for unfamiliar brands/forms and package quantities.

The complete static bundled-catalog audit is docs/ingredient-search-audit.csv (108 recipes, 607 distinct names, 1430 lines). Reproduce it with dart tool/catalog_audit.dart; CI verifies it with --check. It is not current store inventory. Recipe quantities and curated dietary records are preserved. Plain BBQ sauce and ground black pepper use sourced approximate weight estimates for shopping; other unknown densities require manual package review.
