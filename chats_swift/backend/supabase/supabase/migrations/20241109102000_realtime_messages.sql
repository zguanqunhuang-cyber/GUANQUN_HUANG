-- Ensure messages table broadcasts realtime events

alter publication supabase_realtime add table public.messages;
