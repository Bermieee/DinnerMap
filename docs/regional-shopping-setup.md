# Regional shopping setup

DinnerMap 0.4 saves a five-digit US ZIP and search radius, separately from shared household meal plans. Open Household → Stores & prices. Local builds store these preferences only on the device; verified accounts use their own Supabase profile. Local ZIPs are not automatically uploaded when you sign in.

## Enable live Kroger discovery

1. Complete docs/household-setup.md for the existing Supabase account backend.
2. Apply supabase/migrations/202610100001_region.sql after the existing migrations. It adds private account location profiles, a read-only ZIP metadata cache, and a 30-request-per-minute per-account limiter.
3. Create your Kroger developer application with the public Locations and Products APIs. Obtain client credentials on the Kroger developer portal. Keep the secret in backend configuration only.
4. Deploy supabase/functions/retailers with the Supabase CLI after setting KROGER_CLIENT_ID and KROGER_CLIENT_SECRET using Supabase project secrets. The function uses the existing SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY provided to deployed functions. Retain JWT verification; the handler also checks the user and verified email server-side.
5. Build with your SUPABASE_URL and SUPABASE_ANON_KEY as described in the household guide. Sign in, verify the email, save ZIP/radius and use Find nearby stores. Select a returned location, then search a product.

The DinnerMap test project now has all three schemas installed, shared-table Realtime enabled, and the authenticated retailers function deployed. CI uses config/dinnermap-test.json, containing only the public project URL and publishable client key. Kroger credentials are still pending. No Google Play upload is performed.

## Behavior and limitations

ZIP resolution uses https://api.zippopotam.us/us/{zip}; positive results are cached for 30 days. Kroger discovery returns up to 50 locations and product search up to 50 products, preserving each returned item variant. Empty results are not evidence that no other chains serve the area. Walmart and Amazon are marked access pending and do not return offers. Account ZIP values are sent to the ZIP resolver and Kroger when requested; product search terms and selected locations are sent to Kroger. Account preferences remain personal even when family members share a planner.

Price sorting supports low/high package prices and low/high normalized unit prices. Compare weight per pound, volume per fluid ounce, or count per item explicitly; results with incompatible units appear after comparable results. Missing or ambiguous quantities never become calculated unit prices. Multipacks with ambiguous sizes retain the provider’s original size. Kroger promo=0 is treated as no promotion; regular=0 is a known zero price. Prices exclude tax and are not checkout totals. Reported stock level is displayed without claiming guaranteed fulfillment availability.

This milestone searches offers; it does not choose products automatically, transfer carts, or make purchases. Package matching to grocery quantities and broader retailer price comparison follow when provider access and hosted tests are available.

## Acceptance still required

Hosted verified login, migration application, function deployment, ZIP resolution for 40165, selected-store prices and two-account profile isolation need live testing. Offline behavior shows an error while preserving saved ZIP preferences; store results are session-only. Google Play testing and physical foldables remain deferred.

## Reviewed grocery-list estimates (0.5.0)

Generate a shopping list, then choose **Price this list at Kroger**. Select a store, search for a product for each grocery item, review the package size, and confirm the number of packages. Compatible known fixed-package quantities suggest a rounded-up package count. Unknown sizes or units require a manual count; unknown price basis also requires explicit fixed-package confirmation. Variable-weight products are displayed but excluded from fixed-package estimates.

The displayed total is partial until every item is priced. Unpriced items are excluded, and an entirely unpriced list shows a dash rather than zero. The estimate includes checked list items and manual items; it excludes tax, delivery fees, coupons and variable-weight checkout adjustments. Store or ingredient quantity changes invalidate selections; a stale shopping list must be regenerated. Selections currently last only while the pricing screen is open and are not shared between household members.

Live acceptance remains pending Kroger application registration and backend credentials. Register a DinnerMap application at https://developer.kroger.com/ and add `KROGER_CLIENT_ID` and `KROGER_CLIENT_SECRET` under Supabase **Edge Functions → Secrets** for project `cmrfydajyhoctunacdvi`. Do not put the client secret in Flutter/web configuration or GitHub source. Once configured, verify ZIP lookup, selected-store product prices, package sizes and account isolation with real results. No cart or checkout integration is included in this milestone.
