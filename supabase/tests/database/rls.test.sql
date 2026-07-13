begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111',
   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'user-a@example.invalid', 'not-a-real-password', now(), now(), now()),
  ('22222222-2222-4222-8222-222222222222',
   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'user-b@example.invalid', 'not-a-real-password', now(), now(), now());

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  true
);

select lives_ok(
  $$insert into public.devices (id, user_id, name, platform)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '11111111-1111-4111-8111-111111111111', 'A', 'test')$$,
  'user A can insert its own device'
);

select throws_ok(
  $$insert into public.devices (id, user_id, name, platform)
    values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      '22222222-2222-4222-8222-222222222222', 'B', 'test')$$,
  '42501',
  null,
  'user A cannot insert a device for user B'
);

reset role;
insert into public.books (
  id, user_id, local_id, profile_local_id, title, format
) values
  ('aaaaaaaa-0000-4000-8000-000000000001',
   '11111111-1111-4111-8111-111111111111', 'book-a', 'principal', 'A', 'text'),
  ('bbbbbbbb-0000-4000-8000-000000000002',
   '22222222-2222-4222-8222-222222222222', 'book-b', 'principal', 'B', 'text');
set local role authenticated;

select is((select count(*)::integer from public.books), 1, 'select only returns own books');
select is((select title from public.books limit 1), 'A', 'other user title is not visible');

select is_empty(
  $$update public.books set title = 'stolen'
    where id = 'bbbbbbbb-0000-4000-8000-000000000002'
    returning id$$,
  'user A cannot update a row owned by user B'
);

select is(
  (select count(*)::integer from public.books
    where id = 'bbbbbbbb-0000-4000-8000-000000000002'),
  0,
  'user B row remains invisible for updates'
);

select lives_ok(
  $$insert into public.reading_progress (
      user_id, local_id, profile_local_id, book_local_id,
      chapter_index, chapter_progress
    ) values (
      '11111111-1111-4111-8111-111111111111', 'progress-a', 'principal',
      'book-a', 3, 0.5
    )$$,
  'user can insert own reading progress'
);

select throws_ok(
  $$insert into public.reading_progress (
      user_id, local_id, profile_local_id, book_local_id
    ) values (
      '22222222-2222-4222-8222-222222222222', 'progress-b', 'principal',
      'book-b'
    )$$,
  '42501',
  null,
  'user cannot insert another user progress'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('veredra-books',
      '11111111-1111-4111-8111-111111111111/book-a/content.txt',
      '11111111-1111-4111-8111-111111111111')$$,
  'user can create an object inside its own storage prefix'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('veredra-books',
      '22222222-2222-4222-8222-222222222222/book-b/content.txt',
      '11111111-1111-4111-8111-111111111111')$$,
  '42501',
  null,
  'user cannot write another user storage prefix'
);

select * from finish();
rollback;
