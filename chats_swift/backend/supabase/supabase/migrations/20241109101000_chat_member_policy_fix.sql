-- Resolve recursion by using helper function for owner lookup

create or replace function public.chat_owner(p_chat_id uuid)
returns uuid as $$
    select owner_id from public.chats where id = p_chat_id limit 1;
$$ language sql security definer;

alter function public.chat_owner(uuid) set search_path = public;

drop policy if exists "insert chat membership" on public.chat_members;

create policy "insert chat membership" on public.chat_members
    for insert
    with check (
        auth.uid() = user_id
        or auth.uid() = public.chat_owner(chat_members.chat_id)
        or auth.role() = 'service_role'
    );
