-- Veredra private book packages for cross-device offline reading.

alter table public.book_assets
  drop constraint if exists book_assets_mime_type_check;

alter table public.book_assets
  add constraint book_assets_mime_type_check
  check (mime_type in (
    'text/plain', 'text/markdown', 'text/html', 'application/epub+zip',
    'application/pdf', 'application/zip', 'image/png', 'image/jpeg',
    'image/webp'
  ));

update storage.buckets
set allowed_mime_types = array[
  'text/plain', 'text/markdown', 'text/html', 'application/epub+zip',
  'application/pdf', 'application/zip', 'image/png', 'image/jpeg',
  'image/webp'
]
where id = 'veredra-books';

drop policy if exists veredra_assets_insert_own on storage.objects;

create policy veredra_assets_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'veredra-books'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) = any (
    array[
      'txt', 'md', 'html', 'htm', 'xhtml', 'epub', 'pdf', 'zip',
      'png', 'jpg', 'jpeg', 'webp'
    ]
  )
);
