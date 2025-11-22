-- 先删除旧的 add_friend，以便调整返回结构
drop function if exists public.add_friend(text, uuid);

-- Update friend request workflow to pending + approval model
create or replace function public.add_friend(phone text, requester_id uuid)
returns table(
    request_id uuid,
    friend_id uuid,
    display_name text,
    status public.friend_request_status
) as $$
declare
    target_id uuid;
    pending_request_id uuid;
begin
    if requester_id is distinct from auth.uid() then
        raise exception '无权发起请求';
    end if;

    select id into target_id from public.profiles where public.profiles.phone = add_friend.phone limit 1;

    if target_id is null then
        raise exception '用户不存在';
    end if;

    if target_id = requester_id then
        raise exception '不能添加自己为好友';
    end if;

    insert into public.friend_requests (requester_id, addressee_id, status)
    values (requester_id, target_id, 'pending')
    on conflict (requester_id, addressee_id) do update set status = 'pending'
    returning id into pending_request_id;

    return query
    select pending_request_id, target_id, p.display_name, 'pending'::public.friend_request_status
    from public.profiles p where p.id = target_id;
end;
$$ language plpgsql security definer;

alter function public.add_friend(phone text, requester_id uuid) set search_path = public;

drop function if exists public.respond_friend_request(uuid, boolean, uuid);

create or replace function public.respond_friend_request(request_id uuid, accept boolean, responder_id uuid)
returns table(
    id uuid,
    status public.friend_request_status
) as $$
declare
    request_record friend_requests%rowtype;
begin
    if responder_id is distinct from auth.uid() then
        raise exception '无权处理该请求';
    end if;

    select * into request_record from public.friend_requests
    where friend_requests.id = respond_friend_request.request_id limit 1;

    if request_record.id is null then
        raise exception '请求不存在';
    end if;

    if request_record.addressee_id is distinct from responder_id then
        raise exception '只有被邀请人才能处理请求';
    end if;

    if accept then
        update public.friend_requests
            set status = 'accepted'
            where id = request_record.id
            returning * into request_record;

        update public.profiles
            set friend_ids = (
                select array_agg(distinct v)
                from unnest(coalesce(friend_ids, '{}'::uuid[]) || request_record.addressee_id) as v
            )
            where id = request_record.requester_id;

        update public.profiles
            set friend_ids = (
                select array_agg(distinct v)
                from unnest(coalesce(friend_ids, '{}'::uuid[]) || request_record.requester_id) as v
            )
            where id = request_record.addressee_id;
    else
        update public.friend_requests
            set status = 'rejected'
            where id = request_record.id
            returning * into request_record;
    end if;

    return query select request_record.id, request_record.status;
end;
$$ language plpgsql security definer;

alter function public.respond_friend_request(request_id uuid, accept boolean, responder_id uuid) set search_path = public;

-- Update friend_requests policies
alter table public.friend_requests enable row level security;

drop policy if exists "create friend request" on public.friend_requests;
drop policy if exists "update own friend request" on public.friend_requests;
create policy "create friend request" on public.friend_requests
    for insert with check (auth.uid() = requester_id);
create policy "update own friend request" on public.friend_requests
    for update using (auth.uid() = requester_id or auth.uid() = addressee_id);
