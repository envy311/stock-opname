-- Schema for the current Kartu Gudang frontend.
-- Run this once in the Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.app_users (
  username text primary key,
  password_hash text not null,
  created_at timestamptz not null default now()
);

insert into public.app_users (username, password_hash)
values ('adminsppgklampitan', crypt('admin123', gen_salt('bf')))
on conflict (username) do nothing;

create or replace function public.authenticate_app_user(p_username text, p_password text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_users
    where username = lower(trim(p_username))
      and password_hash = crypt(p_password, password_hash)
  );
$$;

revoke all on public.app_users from anon, authenticated;
grant execute on function public.authenticate_app_user(text, text) to anon, authenticated;

create table if not exists public.items (
  code text primary key,
  name text not null,
  unit text not null,
  category text,
  location text,
  initial_stock numeric not null default 0 check (initial_stock >= 0),
  min_stock numeric not null default 0 check (min_stock >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  item_code text not null references public.items(code) on delete cascade,
  type text not null check (type in ('in', 'out')),
  qty numeric not null check (qty > 0),
  date date not null,
  doc text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.opname_sessions (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.opname_entries (
  id uuid primary key default gen_random_uuid(),
  opname_id uuid not null references public.opname_sessions(id) on delete cascade,
  item_code text not null references public.items(code) on delete cascade,
  system_qty numeric not null,
  physical_qty numeric not null,
  diff numeric not null,
  note text
);

create table if not exists public.settings (
  id integer primary key default 1 check (id = 1),
  company text not null default 'Nama Perusahaan Anda',
  address text default '',
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_items_updated_at on public.items;
create trigger trg_items_updated_at before update on public.items
for each row execute function public.set_updated_at();

drop trigger if exists trg_settings_updated_at on public.settings;
create trigger trg_settings_updated_at before update on public.settings
for each row execute function public.set_updated_at();

insert into public.settings (id, company, address)
values (1, 'Nama Perusahaan Anda', '')
on conflict (id) do nothing;

alter table public.items enable row level security;
alter table public.transactions enable row level security;
alter table public.opname_sessions enable row level security;
alter table public.opname_entries enable row level security;
alter table public.settings enable row level security;

drop policy if exists "Public read items" on public.items;
create policy "Public read items" on public.items for select using (true);
drop policy if exists "Public write items" on public.items;
create policy "Public write items" on public.items for all using (true) with check (true);

drop policy if exists "Public read transactions" on public.transactions;
create policy "Public read transactions" on public.transactions for select using (true);
drop policy if exists "Public write transactions" on public.transactions;
create policy "Public write transactions" on public.transactions for all using (true) with check (true);

drop policy if exists "Public read opname sessions" on public.opname_sessions;
create policy "Public read opname sessions" on public.opname_sessions for select using (true);
drop policy if exists "Public write opname sessions" on public.opname_sessions;
create policy "Public write opname sessions" on public.opname_sessions for all using (true) with check (true);

drop policy if exists "Public read opname entries" on public.opname_entries;
create policy "Public read opname entries" on public.opname_entries for select using (true);
drop policy if exists "Public write opname entries" on public.opname_entries;
create policy "Public write opname entries" on public.opname_entries for all using (true) with check (true);

drop policy if exists "Public read settings" on public.settings;
create policy "Public read settings" on public.settings for select using (true);
drop policy if exists "Public write settings" on public.settings;
create policy "Public write settings" on public.settings for all using (true) with check (true);
