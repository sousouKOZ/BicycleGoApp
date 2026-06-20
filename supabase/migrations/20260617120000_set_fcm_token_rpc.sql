-- 端末の FCM トークンを「常に1ユーザーだけ」に対応させる RPC。
--
-- 背景: 同じ端末トークンが複数の users.fcm_token に残ると、アカウント切替や
-- ログアウト後に「旧アカウント宛ての push」がその端末へ誤配信される。
-- そこで登録時に、同トークンを他ユーザー行から剥がしてから呼び出しユーザーへ割り当てる。
-- RLS 上、他ユーザー行の更新はクライアントから不可能なため SECURITY DEFINER で行う。
create or replace function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- 同じ端末トークンを他ユーザーから除去（端末は1ユーザーに対応）。
  update public.users
     set fcm_token = null
   where fcm_token = p_token
     and id <> auth.uid();

  -- 呼び出しユーザー自身へ割り当て。
  update public.users
     set fcm_token = p_token
   where id = auth.uid();
end;
$$;

-- 認証済みユーザー（匿名サインイン含む）のみ実行可能。
revoke all on function public.set_fcm_token(text) from public, anon;
grant execute on function public.set_fcm_token(text) to authenticated;
