-- Social media extension for the existing İş Ağı project.
alter table public.posts add column video_url text;
alter table public.posts add constraint posts_one_media check (num_nonnulls(image_url, video_url) <= 1);
update storage.buckets set file_size_limit=26214400,
 allowed_mime_types=array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']
 where id='post-media';

create table public.stories (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.profiles(id) on delete cascade,
 media_path text not null unique,
 kind text not null check(kind in ('image','video')),
 caption text not null default '' check(char_length(caption)<=500),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '24 hours',
 check(expires_at>created_at and expires_at<=created_at+interval '24 hours')
);
create index stories_recent on public.stories(created_at desc);
create index stories_expiry on public.stories(expires_at);
create index stories_author on public.stories(author_id);
alter table public.stories enable row level security;
revoke all on public.stories from anon, authenticated;
grant select,delete on public.stories to authenticated;
-- The server exclusively controls creation and expiry times.
grant insert(author_id,media_path,kind,caption) on public.stories to authenticated;
create policy "stories active and unblocked" on public.stories for select to authenticated
 using(expires_at>now() and not private.is_blocked(auth.uid(),author_id));
create policy "stories create own" on public.stories for insert to authenticated
 with check(author_id=auth.uid() and split_part(media_path,'/',1)=auth.uid()::text);
create policy "stories delete own" on public.stories for delete to authenticated
 using(author_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('story-media','story-media',false,26214400,
 array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']);
create policy "story media upload own" on storage.objects for insert to authenticated
 with check(bucket_id='story-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "story media active viewers" on storage.objects for select to authenticated
 using(bucket_id='story-media' and ((storage.foldername(name))[1]=auth.uid()::text or exists(
  select 1 from public.stories s where s.media_path=name and s.expires_at>now()
  and not private.is_blocked(auth.uid(),s.author_id))));
create policy "story media delete own" on storage.objects for delete to authenticated
 using(bucket_id='story-media' and (storage.foldername(name))[1]=auth.uid()::text);

