-- Signature: dev.tswicolly03
-- Atomic, user-scoped reading checkpoint updates. Requires existing
-- public.reading_progress RLS (202607130001_auth_sync_schema.sql).
-- Never move the reading position backward merely because an old client syncs.

create or replace function public.veredra_upsert_progress_if_newer(
  p_user_id uuid,
  p_device_id uuid,
  p_local_id text,
  p_remote_id uuid,
  p_data jsonb
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_saved_at timestamptz;
  v_written integer;
begin
  if (select auth.uid()) is distinct from p_user_id then
    raise exception 'Unauthorized reading progress sync'
      using errcode = '42501';
  end if;

  if p_local_id is null
     or length(p_local_id) < 1
     or p_data is null
     or p_data->>'bookId' is distinct from p_local_id
     or jsonb_typeof(p_data->'savedAt') <> 'string'
  then
    raise exception 'Invalid reading progress payload'
      using errcode = '22023';
  end if;

  v_saved_at := (p_data->>'savedAt')::timestamptz;
  if v_saved_at is null then
    raise exception 'Missing reading checkpoint time'
      using errcode = '22023';
  end if;

  insert into public.reading_progress as existing (
    id, user_id, device_id, local_id,
    profile_local_id, book_local_id,
    chapter_index, chapter_progress,
    data, updated_at, deleted_at, version
  )
  values (
    p_remote_id, p_user_id, p_device_id, p_local_id,
    coalesce(nullif(p_data->>'profileId', ''), 'principal'),
    p_local_id,
    coalesce((p_data->>'chapterIndex')::integer, 0),
    coalesce((p_data->>'chapterProgress')::double precision, 0),
    p_data,
    timezone('utc', now()),
    null,
    1
  )
  on conflict (user_id, local_id) do update
    set device_id = excluded.device_id,
        chapter_index = excluded.chapter_index,
        chapter_progress = excluded.chapter_progress,
        profile_local_id = excluded.profile_local_id,
        book_local_id = excluded.book_local_id,
        data = excluded.data,
        updated_at = timezone('utc', now()),
        deleted_at = null,
        version = existing.version + 1
    where coalesce(
      nullif(existing.data->>'savedAt','')::timestamptz,
      '-infinity'::timestamptz
    ) < v_saved_at;

  get diagnostics v_written = row_count;
  return v_written > 0;
end;
$$;

revoke all on function public.veredra_upsert_progress_if_newer(
  uuid, uuid, text, uuid, jsonb
) from public, anon;
grant execute on function public.veredra_upsert_progress_if_newer(
  uuid, uuid, text, uuid, jsonb
) to authenticated;

-- Covers older clients that still call direct table upserts. The new RPC
-- already compares timestamps atomically, but this trigger also prevents a
-- legacy app from replacing a newer checkpoint with an older one.
create or replace function public.veredra_guard_stale_progress_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_existing timestamptz;
  v_incoming timestamptz;
begin
  begin
    v_existing := nullif(old.data->>'savedAt', '')::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then
    v_existing := null;
  end;
  begin
    v_incoming := nullif(new.data->>'savedAt', '')::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then
    v_incoming := null;
  end;

  if v_existing is not null and
      (v_incoming is null or v_incoming <= v_existing) then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists veredra_guard_stale_progress on public.reading_progress;
create trigger veredra_guard_stale_progress
before update on public.reading_progress
for each row execute function public.veredra_guard_stale_progress_update();

revoke all on function public.veredra_guard_stale_progress_update()
  from public, anon, authenticated;
