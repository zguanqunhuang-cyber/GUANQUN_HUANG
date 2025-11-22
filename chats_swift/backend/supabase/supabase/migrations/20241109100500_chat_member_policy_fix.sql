-- Replace chat member insert policy to avoid recursive subquery

alter table public.chat_members enable row level security;

drop policy if exists "insert chat membership" on public.chat_members;

create policy "insert chat membership" on public.chat_members
    for insert
    with check (
        auth.uid() = user_id
        or (auth.uid() = (select chats.owner_id from public.chats where chats.id = chat_members.chat_id limit 1))
        or auth.role() = 'service_role'
    );
