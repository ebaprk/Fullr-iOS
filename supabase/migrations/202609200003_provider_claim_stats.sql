-- Fix: Business, Pantry, and Campus offers were previously excluded.
-- Keep the original restaurant-only RPC for older app versions.
begin;

-- No new tables or columns. Support the time window and provider drill-down.
create index if not exists offers_posted_time_idx on public."Offers" (posted_time desc);
create index if not exists offers_store_posted_time_idx on public."Offers" (store_id, posted_time desc);

-- Aggregates are intentionally visible across food providers to signed-in users.
-- SECURITY DEFINER avoids requiring broad access to claim UUIDs via Offers RLS.
-- Only counts and public provider/offer names leave the database.
create or replace function public.get_provider_claim_stats(
    p_days integer default 30,
    p_store_id uuid default null,
    p_as_of timestamptz default null,
    p_limit integer default 25,
    p_offset integer default 0,
    p_provider_type text default null
)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
    cutoff timestamptz := least(coalesce(p_as_of, now()), now());
    result jsonb;
begin
    if auth.uid() is null then
        raise exception 'Sign in to view provider stats' using errcode = '42501';
    end if;
    if p_days is null or p_days not in (0, 7, 30, 90)
       or p_limit is null or p_limit < 1 or p_limit > 50
       or p_offset is null or p_offset < 0
       or (p_provider_type is not null and p_provider_type not in ('Restaurant', 'Business', 'Pantry', 'Campus')) then
        raise exception 'Invalid stats filter or page' using errcode = '22023';
    end if;

    with offer_stats as materialized (
        select o.offer_id, o.store_id, o.posted_time,
               coalesce(nullif(btrim(o.offer_name), ''), 'Untitled offer') as offer_name,
               s.name as store_name, s.store_type::text as store_type,
               -- Count one claim per user per offer; ignore NULLs and legacy duplicates.
               (select count(distinct claimant)
                from unnest(o.claimed_user_ids) as claims(claimant)) as claim_count
        from public."Offers" o
        join public."Stores" s on s.id = o.store_id
        where (p_provider_type is null or s.store_type::text = p_provider_type)
          and (p_store_id is null or o.store_id = p_store_id)
          and (o.posted_time <= cutoff or (p_days = 0 and o.posted_time is null))
          and (p_days = 0 or o.posted_time >= cutoff - make_interval(days => p_days))
    ), provider_totals as (
        select store_id, store_name, store_type, sum(claim_count)::bigint as claim_count,
               count(*) as offer_count
        from offer_stats group by store_id, store_name, store_type
    ), ranked as (
        select *, dense_rank() over (order by claim_count desc) as rank
        from provider_totals
    ), rows as (
        select rank as position, lower(store_name) as sort_name, store_id as id,
               jsonb_build_object('id', store_id, 'name', store_name, 'provider_type', store_type, 'rank', rank,
                                  'claim_count', claim_count, 'offer_count', offer_count) as data
        from ranked where p_store_id is null
        union all
        select row_number() over (order by claim_count desc, posted_time desc nulls last, offer_id),
               '', offer_id,
               jsonb_build_object('id', offer_id, 'name', offer_name,
                                  'posted_at', posted_time, 'claim_count', claim_count)
        from offer_stats where p_store_id is not null
    ), page as (
        select * from rows order by position, sort_name, id limit p_limit offset p_offset
    )
    select jsonb_build_object(
        'as_of', cutoff,
        'total_claims', coalesce((select sum(claim_count) from offer_stats), 0),
        'total_offers', (select count(*) from offer_stats),
        'total_providers', (select count(*) from provider_totals),
        'items', coalesce((select jsonb_agg(data order by position, sort_name, id) from page), '[]'::jsonb),
        'next_offset', case when (select count(*) from rows) > p_offset + p_limit then p_offset + p_limit else null end
    ) into result;
    return result;
end;
$$;

revoke execute on function public.get_provider_claim_stats(integer, uuid, timestamptz, integer, integer, text) from public, anon;
grant execute on function public.get_provider_claim_stats(integer, uuid, timestamptz, integer, integer, text) to authenticated;

notify pgrst, 'reload schema';
commit;
