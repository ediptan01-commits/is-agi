insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-avatars','profile-avatars',false,5242880,array['image/jpeg','image/png','image/webp']);

create policy "avatar upload own" on storage.objects for insert to authenticated
with check(bucket_id='profile-avatars' and private.account_active() and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatar view profiles" on storage.objects for select to authenticated
using(bucket_id='profile-avatars' and private.account_active() and (
 (storage.foldername(name))[1]=auth.uid()::text or exists(
  select 1 from public.profiles p where p.avatar_url=name and p.id::text=(storage.foldername(name))[1] and not private.is_blocked(auth.uid(),p.id))));
create policy "avatar delete own" on storage.objects for delete to authenticated
using(bucket_id='profile-avatars' and private.account_active() and (storage.foldername(name))[1]=auth.uid()::text);
