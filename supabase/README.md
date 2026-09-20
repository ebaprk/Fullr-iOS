# Offer claim confirmation

Your current schema already includes `claimed_user_ids`. Do not rerun the original add-column migration on that database. For the new Stats tab, run `migrations/202609200003_provider_claim_stats.sql` as described below.

The original `migrations/202609200001_offer_claimed_user_ids.sql` is retained for fresh databases without claim support. Claim buttons require its `get_offer_claim_status` and `set_offer_claim_status` functions as well as the column. No migration has been applied to the hosted database by Codex.

Claim confirmations use this column on the existing `public."Offers"` table:

```sql
claimed_user_ids uuid[] not null default '{}'::uuid[]
```

“Confirm I claimed this” adds the signed-in user's `auth.users.id` to the array. “Undo claim” removes it. An absent ID means not claimed, including users who have never clicked either button. Existing offers start with empty arrays. No new table is created, and `offer_completed` keeps its existing meaning.

The migration also adds two functions used by the app: `get_offer_claim_status` reads the current user's membership, and `set_offer_claim_status` atomically adds/removes it. They derive the user ID from the authenticated session. Repeated claims do not duplicate IDs, and simultaneous claims preserve other users' IDs. A trigger prevents ordinary API clients from overwriting the whole array through existing Offers write permissions. Functions follow [Supabase's database-function guidance](https://supabase.com/docs/guides/database/functions).

The column inherits the existing Offers read permissions, so clients that can select all offer columns can also read the array. UUID arrays do not provide foreign-key cleanup when an auth user is deleted.

## Verify after applying

1. Sign in, open an offer, and tap “Confirm I claimed this”. Confirm your UUID appears once in `Offers.claimed_user_ids` and the selection persists when reopening.
2. Claim the same offer as another user. Confirm both UUIDs remain in the array.
3. Tap “Undo claim” as the first user. Confirm only that user's UUID is removed.
4. Using a user JWT, verify direct array replacement fails, and an anonymous call to either function fails.
5. Interrupt the network during a save. The previous confirmed state should remain visible with a retryable error.
6. Open **You → Claimed offers**. It should show offers whose `claimed_user_ids` contains your UUID, including past offers. Unclaiming an offer removes it from this list. The app reloads after claim changes and supports pull-to-refresh.

The claimed list reads `Offers` using the signed-in user's JWT and an array-contains filter. Your existing Offers SELECT policy must allow authenticated users to read these rows, including expired/completed offers if you want them in the list. No additional column or table is needed for the list.


# Provider leaderboard and stats

With the schema you provided (`Offers.claimed_user_ids` already exists), run **only** `migrations/202609200003_provider_claim_stats.sql` to enable the Stats tab. Do not rerun the earlier add-column migration on an existing column. The new migration adds indexes and one read-only RPC, `get_provider_claim_stats`; it creates no tables or columns. This migration has not been applied to your hosted database.

- Time filters use **offer posted dates**, as requested: rolling 7, 30, or 90 days, or all time. They do not measure when a claim occurred, because the schema stores no claim timestamps.
- Each distinct, non-null UUID counts once per offer. Claiming two offers at one restaurant counts twice. Undoing a claim reduces the current total. These are current confirmations, not lifetime redemption events or independently verified pickups.
- All provider types participate by default. The provider-type menu can limit results to Restaurant, Business, Pantry, or Campus. Expired and completed offers remain eligible; future posted dates are excluded. All-time includes offers with no posted date; dated periods exclude them.
- Restaurants with offers in the selected period appear even with zero claims. Equal totals share a dense rank; names and IDs break display-order ties. Tap a restaurant to see each offer's count, using `offer_name` and its posted date.

The authenticated RPC returns only aggregate counts, provider/offer names, and their IDs. It checks `auth.uid()` and pins an empty `search_path`; it intentionally computes across providers regardless of Offers SELECT policies. No claimant UUIDs are returned, and anonymous callers cannot execute it. Your existing Offers write policies are unchanged. See [Supabase database functions](https://supabase.com/docs/guides/database/functions).

Fetching happens in pages of 25, capped by the server at 50. Filtering, joins, counts, ranks, and totals run in PostgreSQL. Indexes support posted-time and per-store lookups. The app caches results per period and provider type for 60 seconds, reuses concurrent initial loads, cancels superseded requests, ignores late responses, and invalidates caches when a claim changes. Pull-to-refresh bypasses the cache. Offer breakdowns load only when opened; stats never geocode addresses or download claim arrays. Offer-card queries now select only the fields they use.

Pagination keeps the same posted-date cutoff across pages and deduplicates IDs. Claims are live data, so another user's changes can move ranks during pagination; refresh to reconcile the full ranking. This is not a historical snapshot.

## Verification

- `bash Tests/run-stats-tests.sh` — cache expiry, filter changes, duplicate requests, cancellation, late responses, pagination, retry, and invalidation.
- `bash Tests/run-offer-claim-tests.sh` — authenticated claim writes, claimed-list behavior, and stats RPC transport/decoding.
- `Tests/RestaurantStatsSQLTests.mjs` — executes the real stats migration in local PostgreSQL (PGlite), with fixtures for duplicate/null UUIDs, posted-date windows, ties, completed offers, provider-type filtering, pagination, and anonymous rejection. Install `@electric-sql/pglite` in a temporary directory and set `PGLITE_MODULE` to its `dist/index.js` when running the file with Node.

After applying the migration, sign in and open **Stats**. Change periods, open a restaurant, and compare the per-offer counts with that offer's distinct claimed UUIDs. Confirm/undo a claim, return to Stats, and verify the totals update. The isolated tests do not read or write your hosted database.


## Fix for zero counts on Pizza Plus

The store `e9ef1453-5c41-4b47-a13c-bb7df78f7edb` is named Pizza Plus and is classified as `Business`. The original restaurant-only RPC therefore excluded both of its pizza offers before counting their claims. The provider migration adds `get_provider_claim_stats`, which includes all provider types by default and accepts an optional `p_provider_type` filter. The old restaurant RPC remains available for older app versions.

Run `migrations/202609200003_provider_claim_stats.sql` in SQL Editor, rebuild the app, and select **All providers** (or **Businesses**) in Stats. The two supplied offers contribute **2 claims, 2 offers, 1 provider**: the same user claimed two different offers. Their database records and classification have not been changed. The local PostgreSQL regression test reproduces the original zero result and verifies the corrected counts using those offer IDs, timestamps, and user ID.
