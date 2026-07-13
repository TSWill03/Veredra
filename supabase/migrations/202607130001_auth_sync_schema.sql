-- Veredra authentication, offline synchronization and per-user isolation.
create extension if not exists pgcrypto with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table public.devices (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  platform text not null check (char_length(platform) between 1 and 40),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  last_seen_at timestamptz not null default timezone('utc', now())
);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null check (char_length(local_id) between 1 and 200),
  display_name text not null check (char_length(display_name) between 1 and 120),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.user_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  title text not null check (char_length(title) between 1 and 500),
  format text not null check (format in ('text', 'epub', 'pdf')),
  is_favorite boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.book_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  book_id uuid not null references public.books(id) on delete cascade,
  local_id text not null,
  storage_path text not null,
  checksum_sha256 text not null check (checksum_sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (mime_type in (
    'text/plain', 'text/markdown', 'text/html', 'application/epub+zip',
    'application/pdf', 'image/png', 'image/jpeg', 'image/webp'
  )),
  size_bytes bigint not null check (size_bytes between 1 and 104857600),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id),
  unique (user_id, checksum_sha256)
);

create table public.reading_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  book_local_id text not null,
  chapter_index integer not null default 0 check (chapter_index >= 0),
  chapter_progress double precision not null default 0
    check (chapter_progress between 0 and 1),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  book_local_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.annotations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  book_local_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.highlights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  book_local_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.reading_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  local_id text not null,
  profile_local_id text not null,
  book_local_id text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, local_id)
);

create table public.sync_state (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  last_pulled_at timestamptz,
  last_pushed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  unique (user_id, device_id)
);

create table public.sync_operations (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  entity_type text not null check (entity_type in (
    'profile', 'preferences', 'book', 'progress', 'bookmark',
    'annotation', 'highlight', 'readingStats'
  )),
  entity_id uuid not null,
  operation text not null check (operation in ('upsert', 'delete')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  version bigint not null default 1 check (version > 0),
  processed_at timestamptz
);

create index books_user_updated_idx on public.books(user_id, updated_at);
create index progress_user_updated_idx on public.reading_progress(user_id, updated_at);
create index bookmarks_user_updated_idx on public.bookmarks(user_id, updated_at);
create index annotations_user_updated_idx on public.annotations(user_id, updated_at);
create index highlights_user_updated_idx on public.highlights(user_id, updated_at);
create index stats_user_updated_idx on public.reading_stats(user_id, updated_at);
create index sync_operations_user_created_idx
  on public.sync_operations(user_id, created_at);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'devices', 'profiles', 'user_preferences', 'books', 'book_assets',
    'reading_progress', 'bookmarks', 'annotations', 'highlights',
    'reading_stats', 'sync_state', 'sync_operations'
  ]
  loop
    execute format(
      'grant select, insert, update, delete on public.%I to authenticated',
      table_name
    );
    execute format('revoke all on public.%I from anon', table_name);
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)',
      table_name || '_select_own', table_name
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)',
      table_name || '_insert_own', table_name
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',
      table_name || '_update_own', table_name
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)',
      table_name || '_delete_own', table_name
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      table_name || '_set_updated_at', table_name
    );
  end loop;
end;
$$;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'veredra-books',
  'veredra-books',
  false,
  104857600,
  array[
    'text/plain', 'text/markdown', 'text/html', 'application/epub+zip',
    'application/pdf', 'image/png', 'image/jpeg', 'image/webp'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy veredra_assets_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy veredra_assets_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) = any (
    array['txt', 'md', 'html', 'htm', 'xhtml', 'epub', 'pdf', 'png', 'jpg', 'jpeg', 'webp']
  )
);

create policy veredra_assets_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy veredra_assets_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  delete from auth.users where id = caller;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
