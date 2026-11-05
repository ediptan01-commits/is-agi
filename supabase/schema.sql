-- İş Ağı 0.1: Supabase SQL Editor'de bir kez çalıştırın.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', profession text not null default '',
 skills text[] not null default '{}', city text not null default '',
 bio text not null default '', avatar_url text, available boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.blocks (
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id), check(blocker_id <> blocked_id)
);
create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 3000),
 image_url text, created_at timestamptz not null default now()
);
create table if not exists public.likes (
 user_id uuid not null references public.profiles(id) on delete cascade,
 post_id uuid not null references public.posts(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,post_id)
);
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table if not exists public.follows (
 follower_id uuid not null references public.profiles(id) on delete cascade,
 following_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,following_id),check(follower_id <> following_id)
);
create table if not exists public.jobs (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(char_length(title) between 3 and 160),
 description text not null check(char_length(description) between 3 and 4000),
 city text not null default '', category text not null default '',
 status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default now()
);
create table if not exists public.applications (
 id uuid primary key default gen_random_uuid(),
 job_id uuid not null references public.jobs(id) on delete cascade,
 applicant_id uuid not null references public.profiles(id) on delete cascade,
 message text not null default '' check(char_length(message) <= 1000),
 created_at timestamptz not null default now(),unique(job_id,applicant_id)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2000),
 created_at timestamptz not null default now(),check(sender_id <> recipient_id)
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 kind text not null, body text not null,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references public.profiles(id) on delete cascade,
 target_user_id uuid references public.profiles(id) on delete set null,
 target_post_id uuid references public.posts(id) on delete set null,
 reason text not null check(char_length(reason) between 3 and 500),
 created_at timestamptz not null default now(),
 check ((target_user_id is not null) <> (target_post_id is not null))
);

create index if not exists idx_posts_recent on public.posts(created_at desc);
create index if not exists idx_comments_post on public.comments(post_id,created_at);
create index if not exists idx_jobs_recent on public.jobs(created_at desc);
create index if not exists idx_messages_pair on public.messages(sender_id,recipient_id,created_at);
create index if not exists idx_notifications_user on public.notifications(user_id,created_at desc);

-- İki taraf arasında engelleme olup olmadığını RLS döngüsü olmadan sorgula.
create schema if not exists private;
create or replace function private.is_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.blocks where
  (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a));
$$;
revoke all on function private.is_blocked(uuid,uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_blocked(uuid,uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.blocks enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;

create policy "profiles visible" on public.profiles for select to authenticated
 using (id=auth.uid() or not private.is_blocked(auth.uid(),id));
create policy "profiles create own" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "profiles change own" on public.profiles for update to authenticated
 using(id=auth.uid()) with check(id=auth.uid());

create policy "blocks own view" on public.blocks for select to authenticated using(blocker_id=auth.uid());
create policy "blocks own insert" on public.blocks for insert to authenticated with check(blocker_id=auth.uid());
create policy "blocks own delete" on public.blocks for delete to authenticated using(blocker_id=auth.uid());

create policy "posts visible" on public.posts for select to authenticated using(not private.is_blocked(auth.uid(),author_id));
create policy "posts own insert" on public.posts for insert to authenticated with check(author_id=auth.uid());
create policy "posts own update" on public.posts for update to authenticated using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "posts own delete" on public.posts for delete to authenticated using(author_id=auth.uid());

create policy "likes visible" on public.likes for select to authenticated using(
 exists(select 1 from public.posts p where p.id=post_id));
create policy "likes insert" on public.likes for insert to authenticated with check(user_id=auth.uid() and
 exists(select 1 from public.posts p where p.id=post_id and p.author_id<>auth.uid()));
create policy "likes delete" on public.likes for delete to authenticated using(user_id=auth.uid());

create policy "comments visible" on public.comments for select to authenticated using(
 exists(select 1 from public.posts p where p.id=post_id));
create policy "comments insert" on public.comments for insert to authenticated with check(author_id=auth.uid() and
 exists(select 1 from public.posts p where p.id=post_id));
create policy "comments own delete" on public.comments for delete to authenticated using(author_id=auth.uid());

create policy "follows visible" on public.follows for select to authenticated using(
 not private.is_blocked(auth.uid(),follower_id) and not private.is_blocked(auth.uid(),following_id));
create policy "follows insert" on public.follows for insert to authenticated with check(
 follower_id=auth.uid() and not private.is_blocked(follower_id,following_id));
create policy "follows delete" on public.follows for delete to authenticated using(follower_id=auth.uid());

create policy "jobs visible" on public.jobs for select to authenticated using(not private.is_blocked(auth.uid(),owner_id));
create policy "jobs insert" on public.jobs for insert to authenticated with check(owner_id=auth.uid());
create policy "jobs update own" on public.jobs for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "jobs delete own" on public.jobs for delete to authenticated using(owner_id=auth.uid());

create policy "applications visible" on public.applications for select to authenticated using(
 applicant_id=auth.uid() or exists(select 1 from public.jobs j where j.id=job_id and j.owner_id=auth.uid()));
create policy "applications insert" on public.applications for insert to authenticated with check(
 applicant_id=auth.uid() and exists(select 1 from public.jobs j where j.id=job_id and j.status='open'
 and j.owner_id<>auth.uid() and not private.is_blocked(auth.uid(),j.owner_id)));
create policy "applications own delete" on public.applications for delete to authenticated using(applicant_id=auth.uid());

create policy "messages parties read" on public.messages for select to authenticated using(
 (sender_id=auth.uid() or recipient_id=auth.uid()) and not private.is_blocked(sender_id,recipient_id));
create policy "messages send" on public.messages for insert to authenticated with check(
 sender_id=auth.uid() and not private.is_blocked(sender_id,recipient_id));

create policy "notifications own read" on public.notifications for select to authenticated using(user_id=auth.uid());
create policy "notifications own update" on public.notifications for update to authenticated
 using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "reports own create" on public.reports for insert to authenticated with check(
 reporter_id=auth.uid() and (target_user_id is null or target_user_id<>auth.uid()));

-- Yeni kayıtla otomatik profil oluştur.
create or replace function private.new_user_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''))
 on conflict(id) do nothing;
 return new;
end;
$$;
drop trigger if exists is_agi_on_auth_user_created on auth.users;
create trigger is_agi_on_auth_user_created after insert on auth.users for each row execute function private.new_user_profile();

-- Bildirimler istemciden yazılamaz; yalnızca veritabanı tetikler.
create or replace function private.notify_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare target uuid; actor uuid; txt text;
begin
 if TG_TABLE_NAME='follows' then
  target:=new.following_id; actor:=new.follower_id; txt:='Seni takip etmeye başladı';
 elsif TG_TABLE_NAME='likes' then
  select author_id into target from public.posts where id=new.post_id;
  actor:=new.user_id; txt:='Gönderini beğendi';
 elsif TG_TABLE_NAME='comments' then
  select author_id into target from public.posts where id=new.post_id;
  actor:=new.author_id; txt:='Gönderine yorum yaptı';
 elsif TG_TABLE_NAME='applications' then
  select owner_id into target from public.jobs where id=new.job_id;
  actor:=new.applicant_id; txt:='İş ilanına başvurdu';
 elsif TG_TABLE_NAME='messages' then
  target:=new.recipient_id; actor:=new.sender_id; txt:='Yeni mesaj gönderdi';
 end if;
 if target is not null and actor is not null and target<>actor and not private.is_blocked(target,actor) then
  insert into public.notifications(user_id,actor_id,kind,body)
  values(target,actor,TG_TABLE_NAME,txt);
 end if;
 return new;
end;
$$;

do $$ declare tbl text; begin
 foreach tbl in array array['follows','likes','comments','applications','messages'] loop
 execute format('drop trigger if exists notify_insert on public.%I',tbl);
 execute format('create trigger notify_insert after insert on public.%I for each row execute function private.notify_activity()',tbl);
 end loop;
end $$;

-- API tabloları kullanılabilir olsun, RLS her işlemde uygulanır.
grant usage on schema public to authenticated;
grant select,insert,update,delete on public.profiles, public.blocks, public.posts, public.likes, public.comments, public.follows, public.jobs, public.applications, public.messages, public.notifications, public.reports to authenticated;
-- İstemcinin bildirim oluşturmasını ve şikayet kayıtlarını okumasını engelle.
revoke insert,delete on public.notifications from authenticated;
revoke select,update,delete on public.reports from authenticated;
revoke update,delete on public.messages from authenticated;

-- Görsel saklama: kullanıcı kendine ait klasöre yükleyebilir; herkese açık portföy medyası.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('post-media','post-media',true,5242880,array['image/jpeg','image/png','image/webp'])
 on conflict(id) do nothing;
create policy "public post images" on storage.objects for select to authenticated using(bucket_id='post-media');
create policy "upload own post images" on storage.objects for insert to authenticated
 with check(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "delete own post images" on storage.objects for delete to authenticated
 using(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text);

-- Trigger functions must not be callable through application roles.
revoke all on function private.new_user_profile() from public, anon, authenticated;
revoke all on function private.notify_activity() from public, anon, authenticated;
-- Clients may mark notifications as read, but cannot edit their content.
revoke update on public.notifications from authenticated;
grant update(is_read) on public.notifications to authenticated;
