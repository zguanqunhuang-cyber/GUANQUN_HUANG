-- Allow users to create chats and memberships for themselves

create policy "insert own chat" on public.chats
    for insert
    with check (auth.uid() = owner_id);

create policy "insert own membership" on public.chat_members
    for insert
    with check (auth.uid() = user_id or auth.role() = 'service_role');
