-- Allow chat owners to add other members

alter table public.chat_members enable row level security;

drop policy if exists "insert own membership" on public.chat_members;

create policy "insert chat membership" on public.chat_members
    for insert
    with check (
        auth.uid() = user_id
        or auth.uid() = (
            select owner_id from public.chats where chats.id = chat_members.chat_id
        )
    );
