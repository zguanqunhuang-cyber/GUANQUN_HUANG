-- Enable helpful extensions
create extension if not exists "pgcrypto";

-- Profiles table synced with Supabase auth
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    phone text unique,
    display_name text not null,
    avatar_url text,
    status_message text,
    friend_ids uuid[] not null default '{}'::uuid[],
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$ language plpgsql;

create trigger set_profiles_updated_at
    before update on public.profiles
    for each row
    execute procedure public.set_updated_at();

create type public.friend_request_status as enum ('pending', 'accepted', 'rejected');

create table if not exists public.friend_requests (
    id uuid primary key default gen_random_uuid(),
    requester_id uuid not null references public.profiles(id) on delete cascade,
    addressee_id uuid not null references public.profiles(id) on delete cascade,
    status public.friend_request_status not null default 'pending',
    created_at timestamptz not null default now(),
    unique (requester_id, addressee_id)
);

create table if not exists public.chats (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid references public.profiles(id) on delete set null,
    title text,
    is_group boolean not null default false,
    created_at timestamptz not null default now()
);

create table if not exists public.chat_members (
    chat_id uuid not null references public.chats(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    role text not null default 'member',
    joined_at timestamptz not null default now(),
    primary key (chat_id, user_id)
);

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    chat_id uuid not null references public.chats(id) on delete cascade,
    sender_id uuid not null references public.profiles(id) on delete cascade,
    content text not null,
    read_by uuid[] not null default '{}'::uuid[],
    created_at timestamptz not null default now()
);

create index if not exists messages_chat_idx on public.messages(chat_id);
create index if not exists messages_created_idx on public.messages(created_at desc);

create table if not exists public.message_notifications (
    id uuid primary key default gen_random_uuid(),
    chat_id uuid not null references public.chats(id) on delete cascade,
    recipient_id uuid not null references public.profiles(id) on delete cascade,
    preview text not null,
    delivered_at timestamptz,
    created_at timestamptz not null default now()
);

-- View that powers chat list summaries
create or replace view public.chat_summaries as
with last_message as (
    select
        chat_id,
        max(created_at) as last_message_at,
        (array_agg(content order by created_at desc))[1] as last_message_content
    from public.messages
    group by chat_id
)
select
    c.id,
    coalesce(c.title,
        string_agg(p.display_name, ', ' order by p.display_name)
    ) as title,
    coalesce(lm.last_message_content, '') as last_message_preview,
    coalesce(lm.last_message_at, c.created_at) as last_message_at,
    0::int as unread_count,
    array_agg(cm.user_id order by cm.user_id) as participant_ids
from public.chats c
join public.chat_members cm on cm.chat_id = c.id
join public.profiles p on p.id = cm.user_id
left join last_message lm on lm.chat_id = c.id
group by c.id, c.title, lm.last_message_at, lm.last_message_content, c.created_at;

-- Friend RPC to add by phone
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

-- RLS Policies
alter table public.profiles enable row level security;
create policy "profiles are readable" on public.profiles
    for select using (true);
create policy "users can update self" on public.profiles
    for update using (auth.uid() = id or auth.role() = 'service_role');
create policy "users can insert self profile" on public.profiles
    for insert with check (auth.uid() = id or auth.role() = 'service_role');

alter table public.friend_requests enable row level security;
create policy "view own requests" on public.friend_requests
    for select using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "create friend request" on public.friend_requests
    for insert with check (auth.uid() = requester_id);
create policy "update own friend request" on public.friend_requests
    for update using (auth.uid() = requester_id or auth.uid() = addressee_id);

alter table public.chats enable row level security;
create policy "read participating chats" on public.chats
    for select using (exists (
        select 1 from public.chat_members cm
        where cm.chat_id = chats.id and cm.user_id = auth.uid()
    ));

alter table public.chat_members enable row level security;
create policy "view memberships" on public.chat_members
    for select using (user_id = auth.uid() or exists (
        select 1 from public.chat_members cm
        where cm.chat_id = chat_members.chat_id and cm.user_id = auth.uid()
    ));

alter table public.messages enable row level security;
create policy "view chat messages" on public.messages
    for select using (exists (
        select 1 from public.chat_members cm
        where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
    ));
create policy "insert own messages" on public.messages
    for insert with check (sender_id = auth.uid() and exists (
        select 1 from public.chat_members cm
        where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
    ));

alter table public.message_notifications enable row level security;
create policy "view own notifications" on public.message_notifications
    for select using (recipient_id = auth.uid());
