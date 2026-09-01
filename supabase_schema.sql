-- Supabase schema for Kartu Gudang / Stock Management
-- Run this in the Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.items (
  code text primary key,
  name text not null,
  unit text,
  category text,
  location text,
  initial_stock numeric not null default 0,
  min_stock numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id text primary key,
  item_code text not null references public.items(code) on delete cascade,
  type text not null check (type in ('in', 'out')),
  qty numeric not null check (qty > 0),
  date date not null,
  doc text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_opname (
  id text primary key,
  date date not null,
  entries jsonb not null default '[]'::jsonb,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.settings (
  id text primary key default 'default',
  company text not null default 'Nama Perusahaan Anda',
  address text default 'Alamat gudang belum diatur',
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

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

create or replace view public.stock_summary as
select
  i.code,
  i.name,
  i.unit,
  i.location,
  i.min_stock,
  coalesce(i.initial_stock, 0) +
  coalesce((select sum(case when t.type = 'in' then t.qty else -t.qty end)
           from public.transactions t
           where t.item_code = i.code), 0) as current_stock
from public.items i;

alter table public.items enable row level security;
alter table public.transactions enable row level security;
alter table public.stock_opname enable row level security;
alter table public.settings enable row level security;

create policy "Allow read access for all users"
on public.items
for select
using (true);

create policy "Allow write access for all users"
on public.items
for all
using (true)
with check (true);

create policy "Allow read access for all users"
on public.transactions
for select
using (true);

create policy "Allow write access for all users"
on public.transactions
for all
using (true)
with check (true);

create policy "Allow read access for all users"
on public.stock_opname
for select
using (true);

create policy "Allow write access for all users"
on public.stock_opname
for all
using (true)
with check (true);

create policy "Allow read access for all users"
on public.settings
for select
using (true);

create policy "Allow write access for all users"
on public.settings
for all
using (true)
with check (true);

insert into public.settings (id, company, address)
values ('default', 'Nama Perusahaan Anda', 'Alamat gudang belum diatur')
on conflict (id) do nothing;

-- optional seed example
-- insert into public.items (code, name, unit, category, location, initial_stock, min_stock)
-- values ('A001', 'Kopi Bubuk', 'Kg', 'Bahan', 'Rak A', 30, 10),
--        ('B002', 'Gula Pasir', 'Kg', 'Bahan', 'Rak B', 5, 12);
--
-- insert into public.transactions (id, item_code, type, qty, date, doc, note)
-- values ('trx_001', 'A001', 'in', 20, current_date, 'PO', 'Pembelian awal');
