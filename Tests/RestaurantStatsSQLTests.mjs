// Install @electric-sql/pglite in a temporary directory, then run with
// PGLITE_MODULE=/absolute/path/to/node_modules/@electric-sql/pglite/dist/index.js node Tests/RestaurantStatsSQLTests.mjs
// Executes the real migration in an isolated PostgreSQL runtime; no hosted data.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { PGlite } = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const db = new PGlite();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const asOf = '2020-09-20T00:00:00Z';
try {
  await db.exec(`
    create role authenticated;
    create role anon;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to authenticated, anon;
    create type public."StoreType" as enum ('Pantry', 'Business', 'Campus', 'Restaurant');
    create table public."Stores" (id uuid primary key, name text, store_type public."StoreType");
    create table public."Offers" (
      offer_id uuid primary key, store_id uuid references public."Stores", posted_time timestamptz,
      offer_name text, offer_completed bool default false, claimed_user_ids uuid[]
    );
    alter table public."Offers" enable row level security;
    -- Deliberately no Offers SELECT policy: aggregate RPC must still work.
  `);
  await db.exec(await readFile(new URL('../supabase/migrations/202609200002_restaurant_claim_stats.sql', import.meta.url), 'utf8'));
  for (const [n, name, type] of [[1, 'Apple Cafe', 'Restaurant'], [2, 'Birch', 'Restaurant'], [3, 'Cedar', 'Restaurant'], [4, 'Pantry', 'Pantry']]) {
    await db.query('insert into public."Stores" values ($1, $2, $3)', [id(n), name, type]);
  }
  const fixtures = [
    [10, 1, '2020-09-18', 'Bagels', [id(100), id(100), null, id(101)], true],
    [11, 1, '2020-08-01', 'Older offer', [id(100)], false],
    [12, 2, '2020-09-19', 'Bowls', [id(100), id(101)], false],
    [13, 3, '2020-09-15', 'Zero claims', null, false],
    [14, 4, '2020-09-19', 'Pantry offer', [id(100), id(101), id(102)], false],
    [15, 1, '2020-09-21', 'Future offer', [id(100)], false],
    [16, 1, null, 'Undated offer', [id(100)], false],
  ];
  for (const [offer, store, posted, name, claims, completed] of fixtures) {
    await db.query('insert into public."Offers" values ($1,$2,$3,$4,$5,$6)', [id(offer), id(store), posted, name, completed, claims]);
  }
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id(100)}', false);`);
  const stats = async (days, store = null, limit = 25, offset = 0) => {
    const result = await db.query('select public.get_restaurant_claim_stats($1,$2,$3,$4,$5) as data', [days, store, asOf, limit, offset]);
    return result.rows[0].data;
  };
  const week = await stats(7);
  assert.equal(week.total_claims, 4);
  assert.equal(week.total_offers, 3);
  assert.equal(week.total_restaurants, 3);
  assert.deepEqual(week.items.map(x => [x.name, x.rank, x.claim_count]), [['Apple Cafe', 1, 2], ['Birch', 1, 2], ['Cedar', 2, 0]]);
  assert(!JSON.stringify(week).includes(id(100)), 'Never return claimant identities');
  assert.equal((await stats(30)).total_claims, 4);
  assert.equal((await stats(90)).total_claims, 5);
  assert.equal((await stats(0)).total_claims, 6, 'All-time includes undated offers but excludes future offers');
  const offers = await stats(7, id(1));
  assert.equal(offers.total_claims, 2);
  assert.deepEqual(offers.items.map(x => x.name), ['Bagels']);
  assert.equal(offers.items[0].claim_count, 2, 'Ignore duplicate and NULL UUIDs, retain completed offers');
  const page1 = await stats(7, null, 1, 0);
  const page2 = await stats(7, null, 1, 1);
  const page3 = await stats(7, null, 1, 2);
  assert.deepEqual([page1.next_offset, page2.next_offset, page3.next_offset], [1, 2, null]);
  assert.equal(page2.items[0].name, 'Birch');
  assert.equal(page2.total_claims, 4, 'Totals must cover all pages');
  const empty = await stats(7, id(999));
  assert.equal(empty.total_claims, 0);
  assert.deepEqual(empty.items, []);
  assert.equal(empty.next_offset, null);
  await assert.rejects(() => stats(2), /Invalid stats filter/);
  await assert.rejects(() => stats(7, null, 51), /Invalid stats filter/);
  await assert.rejects(() => stats(7, null, 25, -1), /Invalid stats filter/);
  // Regression for the user's Pizza Plus records: it is a Business, not Restaurant.
  await db.exec('reset role');
  await db.exec(await readFile(new URL('../supabase/migrations/202609200003_provider_claim_stats.sql', import.meta.url), 'utf8'));
  const pizzaID = 'e9ef1453-5c41-4b47-a13c-bb7df78f7edb';
  const claimant = 'f78c03c8-18cc-406d-8fbb-03b70e634e70';
  await db.query('insert into public."Stores" values ($1,$2,$3)', [pizzaID, 'Pizza Plus', 'Business']);
  for (const [offerID, posted] of [
    ['11d1f461-2d32-4135-84e9-752488bb2069', '2026-09-20T20:27:27.688Z'],
    ['4867c1a7-53ff-41b9-8dd0-be67c01d11b6', '2026-09-20T20:17:53.409Z'],
  ]) {
    await db.query('insert into public."Offers" values ($1,$2,$3,$4,$5,$6)', [offerID, pizzaID, posted, 'pizza', false, [claimant]]);
  }
  await db.exec('set role authenticated');
  const providerStats = async (scope = null, store = null) => {
    const result = await db.query('select public.get_provider_claim_stats($1,$2,$3,$4,$5,$6) as data',
      [7, store, '2026-09-20T23:59:59Z', 25, 0, scope]);
    return result.rows[0].data;
  };
  const oldPizzaStats = await db.query('select public.get_restaurant_claim_stats(7,null,$1,25,0) as data', ['2026-09-20T23:59:59Z']);
  assert.equal(oldPizzaStats.rows[0].data.total_claims, 0, 'Reproduce the old zero-stats bug');
  const allProviders = await providerStats();
  assert.equal(allProviders.total_claims, 2);
  assert.equal(allProviders.total_offers, 2);
  assert.equal(allProviders.total_providers, 1);
  assert.equal(allProviders.items[0].name, 'Pizza Plus');
  assert.equal(allProviders.items[0].provider_type, 'Business');
  assert.equal((await providerStats('Business')).total_claims, 2);
  assert.equal((await providerStats('Restaurant')).total_claims, 0);
  const pizzaOffers = await providerStats(null, pizzaID);
  assert.equal(pizzaOffers.items.length, 2);
  assert(pizzaOffers.items.every(offer => offer.claim_count === 1));
  await assert.rejects(() => providerStats('Invalid'), /Invalid stats filter/);
  await db.exec("select set_config('request.jwt.claim.sub', '', false)");
  await assert.rejects(() => stats(7), /Sign in/);
  await assert.rejects(() => providerStats(), /Sign in/);
  await db.exec('reset role; set role anon;');
  await assert.rejects(() => stats(7), /permission denied/);
  await assert.rejects(() => providerStats(), /permission denied/);
  console.log('SQL stats tests passed: Pizza Plus Business regression (2 claims), provider filters, ranking, ties, distinct claims, windows, nulls, completed offers, drill-down, pagination, and authentication.');
} finally {
  await db.close();
}
