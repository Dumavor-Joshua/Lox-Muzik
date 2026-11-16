create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  artist text not null,
  artist_names text[] not null default '{}',
  owner_email text not null,
  upload_source text not null default 'web',
  file_name text not null,
  audio_url text not null,
  cover_url text,
  release_type text not null default 'single'
    check (release_type in ('single', 'album', 'mix')),
  genre text,
  allow_streaming boolean not null default true,
  allow_offline boolean not null default true,
  allow_download_to_phone boolean not null default true,
  allow_video_use boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists songs_created_at_idx on public.songs (created_at desc);
alter table public.songs enable row level security;
revoke select on table public.songs from anon, authenticated;
grant select (
  id,
  title,
  artist,
  artist_names,
  upload_source,
  file_name,
  audio_url,
  cover_url,
  release_type,
  genre,
  allow_streaming,
  allow_offline,
  allow_download_to_phone,
  allow_video_use,
  created_at
) on public.songs to anon, authenticated;
grant insert on public.songs to authenticated;

drop policy if exists "Anyone can read streamable songs" on public.songs;
create policy "Anyone can read streamable songs"
  on public.songs for select
  to anon, authenticated
  using (allow_streaming);

drop policy if exists "Creators can read their own songs" on public.songs;
create policy "Creators can read their own songs"
  on public.songs for select
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "Creators can publish their own songs" on public.songs;
create policy "Creators can publish their own songs"
  on public.songs for insert
  to authenticated
  with check (lower(owner_email) = lower(auth.jwt() ->> 'email'));

create or replace function public.get_my_songs()
returns table (
  id uuid,
  title text,
  artist text,
  artist_names text[],
  file_name text,
  audio_url text,
  cover_url text,
  release_type text,
  genre text,
  allow_streaming boolean,
  allow_offline boolean,
  allow_download_to_phone boolean,
  allow_video_use boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    song.id,
    song.title,
    song.artist,
    song.artist_names,
    song.file_name,
    song.audio_url,
    song.cover_url,
    song.release_type,
    song.genre,
    song.allow_streaming,
    song.allow_offline,
    song.allow_download_to_phone,
    song.allow_video_use,
    song.created_at
  from public.songs as song
  where lower(song.owner_email) = lower((select auth.jwt() ->> 'email'))
  order by song.created_at desc;
$function$;

revoke all on function public.get_my_songs() from public, anon;
grant execute on function public.get_my_songs() to authenticated;

insert into storage.buckets (id, name, public)
values
  ('music-files', 'music-files', false),
  ('artist-covers', 'artist-covers', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Anyone can read Lox Muzik media" on storage.objects;
drop policy if exists "Anyone can read Lox Muzik artist covers" on storage.objects;
create policy "Anyone can read Lox Muzik artist covers"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'artist-covers');

drop policy if exists "Listeners can access streamable songs and creators can access their own" on storage.objects;
create policy "Listeners can access streamable songs and creators can access their own"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'music-files'
    and (
      (storage.foldername(storage.objects.name))[1] = trim(
        both '-' from regexp_replace(lower(auth.jwt() ->> 'email'), '[^a-z0-9]+', '-', 'g')
      )
      or exists (
        select 1
        from public.songs as song
        where (
          song.audio_url = storage.objects.name
          or right(
            song.audio_url,
            length('/storage/v1/object/public/music-files/' || storage.objects.name)
          ) = '/storage/v1/object/public/music-files/' || storage.objects.name
        )
        and song.allow_streaming
      )
    )
  );

drop policy if exists "Users can upload their own Lox Muzik media" on storage.objects;
create policy "Users can upload their own Lox Muzik media"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id in ('music-files', 'artist-covers')
    and (storage.foldername(name))[1] = trim(
      both '-' from regexp_replace(lower(auth.jwt() ->> 'email'), '[^a-z0-9]+', '-', 'g')
    )
  );

drop policy if exists "Users can remove their own Lox Muzik media" on storage.objects;
create policy "Users can remove their own Lox Muzik media"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id in ('music-files', 'artist-covers')
    and (storage.foldername(name))[1] = trim(
      both '-' from regexp_replace(lower(auth.jwt() ->> 'email'), '[^a-z0-9]+', '-', 'g')
    )
  );

update public.songs
set audio_url = regexp_replace(
  audio_url,
  '^https?://[^/]+/storage/v1/object/(?:public|sign)/music-files/',
  ''
)
where audio_url like '%/storage/v1/object/%/music-files/%';
