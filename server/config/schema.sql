-- Enable necessary extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Create auth schema if it doesn't exist
create schema if not exists auth;

-- Create auth.users table
create table if not exists auth.users (
  id uuid primary key default uuid_generate_v4(),
  email text unique not null,
  encrypted_password text,
  email_confirmed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Users Table
create table users (
  id uuid default uuid_generate_v4() primary key,
  user_name text not null unique,
  email text not null unique,
  password text not null,
  role text default 'user',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Products Table
create table products (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  price decimal(10,2) not null,
  stock_quantity integer not null default 0,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Orders Table
create table orders (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references users(id) on delete cascade,
  status text not null default 'pending',
  total_amount decimal(10,2) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Order Items Table
create table order_items (
  id uuid default uuid_generate_v4() primary key,
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  quantity integer not null,
  price_at_time decimal(10,2) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Cart Table
create table cart_items (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references users(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  quantity integer not null default 1,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, product_id)
);

-- Reviews Table
create table reviews (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references users(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  rating integer not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, product_id)
);

-- Addresses Table
create table addresses (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references users(id) on delete cascade,
  street_address text not null,
  city text not null,
  state text not null,
  postal_code text not null,
  country text not null,
  is_default boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table users enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table cart_items enable row level security;
alter table reviews enable row level security;
alter table addresses enable row level security;

-- Create policies
create policy "Users can view their own data" on users
  for select using (auth.uid()::uuid = id);

create policy "Anyone can view products" on products
  for select using (true);

create policy "Admin can manage products" on products
  for all using (
    auth.uid()::uuid in (
      select id from users where role = 'admin'
    )
  );

create policy "Users can manage their own orders" on orders
  for all using (auth.uid()::uuid = user_id);

create policy "Users can manage their own cart" on cart_items
  for all using (auth.uid()::uuid = user_id);

create policy "Users can manage their own reviews" on reviews
  for all using (auth.uid()::uuid = user_id);

create policy "Users can manage their own addresses" on addresses
  for all using (auth.uid()::uuid = user_id);

-- Create function to handle user creation
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, user_name, role)
  values (
    new.id,
    new.email,
    new.email, -- Initially set username to email
    case 
      when new.email = 'nishimwejoseph26@gmail.com' then 'admin'
      else 'user'
    end
  );
  return new;
end;
$$ language plpgsql security definer;

-- Create trigger for new user signup
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Insert initial admin user if not exists
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at)
SELECT 
  'nishimwejoseph26@gmail.com',
  crypt('k@#+ymej@AQ@3', gen_salt('bf')),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'nishimwejoseph26@gmail.com'
);
