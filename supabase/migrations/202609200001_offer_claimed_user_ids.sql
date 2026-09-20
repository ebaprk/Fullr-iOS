begin;

alter table public."Offers"
    add column claimed_user_ids uuid[] not null default '{}'::uuid[];

-- Read only the caller's membership; a missing offer is an error.
create function public.get_offer_claim_status(p_offer_id uuid)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
    caller_id uuid := auth.uid();
    claimed boolean;
begin
    if caller_id is null then
        raise exception 'Sign in to check claim status' using errcode = '42501';
    end if;
    select caller_id = any(o.claimed_user_ids) into claimed
    from public."Offers" o where o.offer_id = p_offer_id;
    if not found then
        raise exception 'Offer not found' using errcode = 'P0002';
    end if;
    return claimed;
end;
$$;

-- One atomic UPDATE preserves other users' claims during concurrent requests.
-- The caller cannot supply somebody else's user ID.
create function public.set_offer_claim_status(p_offer_id uuid, p_claimed boolean)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
declare
    caller_id uuid := auth.uid();
    saved boolean;
begin
    if caller_id is null then
        raise exception 'Sign in to change claim status' using errcode = '42501';
    end if;
    if p_claimed is null then
        raise exception 'Claim status is required' using errcode = '22004';
    end if;
    update public."Offers" o
    set claimed_user_ids = case
        when not p_claimed then array_remove(o.claimed_user_ids, caller_id)
        when caller_id = any(o.claimed_user_ids) then o.claimed_user_ids
        else array_append(o.claimed_user_ids, caller_id)
    end
    where o.offer_id = p_offer_id
    returning caller_id = any(o.claimed_user_ids) into saved;
    if not found then
        raise exception 'Offer not found' using errcode = 'P0002';
    end if;
    return saved;
end;
$$;

-- Existing Offers write policies may be broad. Require ordinary API clients
-- to use the function above instead of replacing the entire array directly.
-- This trigger runs as the caller; the SECURITY DEFINER function runs as its owner.
create function public.protect_offer_claimed_user_ids()
returns trigger
language plpgsql security invoker
set search_path = ''
as $$
begin
    if current_user in ('anon', 'authenticated') then
        if tg_op = 'INSERT' then
            if new.claimed_user_ids is distinct from '{}'::uuid[] then
                raise exception 'Use set_offer_claim_status to change claims' using errcode = '42501';
            end if;
        elsif new.claimed_user_ids is distinct from old.claimed_user_ids then
            raise exception 'Use set_offer_claim_status to change claims' using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

create trigger protect_offer_claimed_user_ids
before insert or update on public."Offers"
for each row execute function public.protect_offer_claimed_user_ids();

revoke execute on function public.get_offer_claim_status(uuid) from public, anon;
revoke execute on function public.set_offer_claim_status(uuid, boolean) from public, anon;
revoke execute on function public.protect_offer_claimed_user_ids() from public, anon, authenticated;
grant execute on function public.get_offer_claim_status(uuid) to authenticated;
grant execute on function public.set_offer_claim_status(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
commit;
