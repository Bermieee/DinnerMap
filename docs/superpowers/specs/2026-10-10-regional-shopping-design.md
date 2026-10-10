# DinnerMap regional shopping

Implement the second milestone authorized by the user on October 9. Proceed inline while Google Play setup and live account testing are postponed.

Each account has a private five-digit US ZIP and a search radius (5–100 miles, default 25). Leading zeroes are preserved. No automatic ZIP assignment. ZIP edits clear selected stores and previous offers. Household membership does not grant access to another member’s location preferences. Local demo users can save device preferences independently.

Region metadata comes from an explicit ZIP lookup; invalid/unresolved ZIPs remain unresolved rather than inferred from numerical ranges. Nearby chains derive from returned locations. Supabase tables store validated ZIP metadata and private profile preferences; a server function resolves ZIPs and calls Kroger with secrets supplied by deployment configuration.

Add a Stores page reachable from the Household tab. It saves ZIP/radius, resolves city/state, discovers actual Kroger locations, lets the user choose a store, and searches products at that location. Show provider, store, size, availability and retrieval time. Unknown prices sort last in either direction. Package price and normalized unit price are different sort modes; mass and volume are not compared. No cart transfers in this milestone. Walmart and Amazon expose unavailable capabilities until approved access exists; never fabricated offers.

Backend: authenticated Supabase Edge Function delegates pure request/normalization logic to a testable module. Verify the account server-side, bound input sizes and radius, impose request timeouts, and rate-limit per authenticated user via database RPC. Cache Kroger access tokens only in memory, retry a rejected token once, and never return upstream secrets/errors. ZIP lookup is through Zippopotam.us US endpoint; cache positive results in the regional ZIP table. External service failure is recoverable and does not overwrite a saved profile.

Flutter persistence: Supabase profile repository when a verified session exists, shared preferences for local demo. Key the regional controller by authenticated user; discard late responses after ZIP/store/account changes. Never send local demo preferences to an account automatically. Save before discovery and disable overlapping operations. Errors preserve editable ZIP text, selected store and prior data as appropriate; new searches clear stale results.

Validation: ZIP leading zeroes, radius limits, ownership and anonymous denial; changing ZIP clears selected stores; stale responses discarded; Kroger missing price/size and multiple items preserved; package/unit sorts and unavailable providers; mobile/tablet forms. Existing suites plus Android/web builds through CI. No hosted deployment, paid service, store purchases or live retailer validation without configuration.
