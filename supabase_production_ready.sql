-- Production-safe Supabase schema for Kartu Gudang
-- This version assumes users authenticate via Supabase Auth.
-- Each user has a profile, and data is scoped by that profile.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  company_name text default 'Nama Perusahaan Anda',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  code text not null,
  name text not null,
  unit text,
  category text,
  location text,
  initial_stock numeric not null default 0,
  min_stock numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, code)
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  type text not null check (type in ('in','out')),
  qty numeric not null check (qty > 0),
  date date not null,
  doc text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_opname (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  entries jsonb not null default '[]'::jsonb,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.settings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  company text not null default 'Nama Perusahaan Anda',
  address text default 'Alamat gudang belum diatur',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, company_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'User'), coalesce(new.raw_user_meta_data ->> 'company_name', 'Nama Perusahaan Anda'))
  on conflict (id) do nothing;

  insert into public.settings (profile_id, company, address)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'company_name', 'Nama Perusahaan Anda'), 'Alamat gudang belum diatur')
  on conflict (profile_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_items_updated_at on public.items;
create trigger trg_items_updated_at
before update on public.items
for each row
execute function public.set_updated_at();

drop trigger if exists trg_settings_updated_at on public.settings;
create trigger trg_settings_updated_at
before update on public.settings
for each row
execute function public.set_updated_at();

-- Optional helper view for stock calculation
create or replace view public.stock_summary as
select
  i.id,
  i.profile_id,
  i.code,
  i.name,
  i.unit,
  i.location,
  i.min_stock,
  i.initial_stock + coalesce(sum(case when t.type = 'in' then t.qty else -t.qty end), 0) as current_stock
from public.items i
left join public.transactions t
  on t.profile_id = i.profile_id and t.item_id = i.id
group by i.id, i.profile_id, i.code, i.name, i.unit, i.location, i.min_stock, i.initial_stock;

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.transactions enable row level security;
alter table public.stock_opname enable row level security;
alter table public.settings enable row level security;

-- Profiles: user can only read and update own row.
create policy "Users can read own profile"
on public.profiles
for select
using (auth.uid() = id);

create policy "Users can insert own profile"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Items: users access only their own data.
create policy "Users can read own items"
on public.items
for select
using (auth.uid() = profile_id);

create policy "Users can create own items"
on public.items
for insert
with check (auth.uid() = profile_id);

create policy "Users can update own items"
on public.items
for update
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "Users can delete own items"
on public.items
for delete
using (auth.uid() = profile_id);

-- Transactions: scoped to the same profile.
create policy "Users can read own transactions"
on public.transactions
for select
using (auth.uid() = profile_id);

create policy "Users can create own transactions"
on public.transactions
for insert
with check (auth.uid() = profile_id);

create policy "Users can update own transactions"
on public.transactions
for update
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "Users can delete own transactions"
on public.transactions
for delete
using (auth.uid() = profile_id);

-- Stock opname: scoped to the same profile.
create policy "Users can read own stock opname"
on public.stock_opname
for select
using (auth.uid() = profile_id);

create policy "Users can create own stock opname"
on public.stock_opname
for insert
with check (auth.uid() = profile_id);

create policy "Users can update own stock opname"
on public.stock_opname
for update
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "Users can delete own stock opname"
on public.stock_opname
for delete
using (auth.uid() = profile_id);

-- Settings: scoped to the same profile.
create policy "Users can read own settings"
on public.settings
for select
using (auth.uid() = profile_id);

create policy "Users can create own settings"
on public.settings
for insert
with check (auth.uid() = profile_id);

create policy "Users can update own settings"
on public.settings
for update
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "Users can delete own settings"
on public.settings
for delete
using (auth.uid() = profile_id);

-- Example trigger to ensure profile exists and that the user can only own profile-scoped rows.
-- The app must send profile_id = auth.uid() when inserting.
--
-- Example insert:
-- insert into public.items (profile_id, code, name, unit, category, location, initial_stock, min_stock)
-- values (auth.uid(), 'A001', 'Kopi Bubuk', 'Kg', 'Bahan', 'Rak A', 30, 10);

-- Optional default company name from auth metadata:
-- after sign up, the app can set user metadata: { full_name: 'Budi', company_name: 'Gudang Budi' }
