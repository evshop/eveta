-- 073_eveta_core_clean_schema.sql
-- Baseline public schema for eveta CORE (no historical data).
-- Foreign keys to auth.users are OMITTED so Shop / Portal / Delivery can live in separate Auth projects.
-- RLS policies are NOT included — copy from legacy with a follow-up migration or export pg_policies from old project.
-- Trigger helpers + updated_at triggers included.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

CREATE TYPE public.ticket_benefit_state AS ENUM ('blocked', 'active', 'complete');
CREATE TYPE public.wallet_topup_status AS ENUM (
  'pending_proof',
  'pending_review',
  'approved',
  'rejected',
  'expired'
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_orders_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_profiles_delivery_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_profiles_portal_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_wallet_accounts_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  full_name text,
  avatar_url text,
  phone text,
  address text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  email text,
  username text,
  phone_verified_at timestamptz
);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4 (),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  icon text,
  image_url text,
  description text,
  parent_id uuid REFERENCES public.categories (id),
  created_at timestamptz DEFAULT now(),
  spec_template_enabled boolean NOT NULL DEFAULT false,
  spec_field_labels text[] NOT NULL DEFAULT '{}'::text[],
  spec_group_title text
);

COMMENT ON COLUMN public.categories.spec_template_enabled IS 'Si true, los productos de esta categoría pueden rellenar bloques según spec_field_labels.';
COMMENT ON COLUMN public.categories.spec_field_labels IS 'Títulos de sección en orden (ej. Pantalla, Procesador).';
COMMENT ON COLUMN public.categories.spec_group_title IS 'Encabezado en tienda/admin; lo escribe el usuario al definir la plantilla en la subcategoría.';

CREATE TABLE public.profiles_portal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  auth_user_id uuid UNIQUE,
  legacy_profile_id uuid UNIQUE REFERENCES public.profiles (id) ON DELETE SET NULL,
  email text NOT NULL UNIQUE,
  full_name text,
  is_admin boolean NOT NULL DEFAULT false,
  is_seller boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  avatar_url text,
  phone text,
  address text,
  username text,
  phone_verified_at timestamptz,
  shop_name text,
  shop_description text,
  shop_logo_url text,
  shop_banner_url text,
  is_partner_verified boolean NOT NULL DEFAULT false,
  partner_display_order integer NOT NULL DEFAULT 0,
  shop_border_color text,
  shop_address text,
  shop_lat numeric CHECK (
    shop_lat IS NULL
    OR shop_lat >= '-90'::integer::numeric
    AND shop_lat <= 90::numeric
  ),
  shop_lng numeric CHECK (
    shop_lng IS NULL
    OR shop_lng >= '-180'::integer::numeric
    AND shop_lng <= 180::numeric
  ),
  shop_location_photos jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (
    jsonb_typeof(shop_location_photos) = 'array'::text
    AND jsonb_array_length(shop_location_photos) <= 3
  )
);

COMMENT ON COLUMN public.profiles_portal.shop_address IS 'Dirección física de la tienda para recojo (cuenta Portal).';
COMMENT ON COLUMN public.profiles_portal.shop_lat IS 'Latitud de la ubicación única de la tienda (cuenta Portal).';
COMMENT ON COLUMN public.profiles_portal.shop_lng IS 'Longitud de la ubicación única de la tienda (cuenta Portal).';
COMMENT ON COLUMN public.profiles_portal.shop_location_photos IS 'Fotos del frente/interior del local (max 3 URLs) para Delivery.';

CREATE TABLE public.profiles_delivery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  auth_user_id uuid UNIQUE,
  legacy_profile_id uuid UNIQUE REFERENCES public.profiles (id) ON DELETE SET NULL,
  email text NOT NULL UNIQUE,
  full_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  is_online boolean NOT NULL DEFAULT false
);

COMMENT ON COLUMN public.profiles_delivery.is_online IS 'Si true, el repartidor está disponible para ver pedidos y la tienda puede ofrecer delivery.';

CREATE TABLE public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  name text NOT NULL,
  description text,
  banner_url text,
  location text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.event_ticket_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  event_id uuid NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price >= 0::numeric),
  people_count integer NOT NULL CHECK (people_count > 0),
  benefits jsonb NOT NULL DEFAULT '[]'::jsonb,
  stock integer CHECK (stock IS NULL OR stock >= 0),
  sold_count integer NOT NULL DEFAULT 0 CHECK (sold_count >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4 (),
  seller_id uuid NOT NULL REFERENCES public.profiles_portal (id) ON DELETE CASCADE,
  category_id uuid REFERENCES public.categories (id),
  name text NOT NULL,
  description text,
  price numeric NOT NULL,
  original_price numeric,
  stock integer DEFAULT 0,
  images text[] DEFAULT '{}'::text[],
  unit text DEFAULT 'unidad'::text,
  is_active boolean DEFAULT true,
  is_featured boolean DEFAULT false,
  rating numeric DEFAULT 0,
  review_count integer DEFAULT 0,
  tags text[] DEFAULT '{}'::text[],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  images_layout jsonb NOT NULL DEFAULT '[]'::jsonb,
  specs_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  event_ticket_type_id uuid REFERENCES public.event_ticket_types (id) ON DELETE SET NULL
);

COMMENT ON COLUMN public.products.specs_json IS 'Array JSON: [{"label":"Pantalla","value":"texto multilínea"}, ...] en el mismo orden que la plantilla.';

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4 (),
  buyer_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'::text CHECK (
    status = ANY (
      ARRAY[
        'pending'::text,
        'confirmed'::text,
        'shipped'::text,
        'delivered'::text,
        'cancelled'::text
      ]
    )
  ),
  total numeric NOT NULL,
  delivery_address text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  seller_id uuid REFERENCES public.profiles_portal (id) ON DELETE CASCADE,
  subtotal numeric NOT NULL DEFAULT 0,
  delivery_fee numeric NOT NULL DEFAULT 0,
  distance_km numeric,
  delivery_status text NOT NULL DEFAULT 'awaiting_driver'::text,
  driver_id uuid,
  dropoff_address text,
  dropoff_lat double precision,
  dropoff_lng double precision,
  pickup_lat double precision,
  pickup_lng double precision,
  currency text NOT NULL DEFAULT 'Bs'::text,
  buyer_display_name text
);

COMMENT ON COLUMN public.orders.buyer_display_name IS 'Etiqueta legible del comprador para la app Delivery (evita SELECT en profiles).';

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4 (),
  order_id uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products (id),
  seller_id uuid NOT NULL REFERENCES public.profiles_portal (id) ON DELETE CASCADE,
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  name_snapshot text NOT NULL DEFAULT ''::text,
  price_unit numeric NOT NULL DEFAULT 0,
  line_total numeric NOT NULL DEFAULT 0,
  image_url text
);

CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4 (),
  product_id uuid NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
  buyer_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.phone_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  phone text NOT NULL,
  code_hash text NOT NULL,
  provider text NOT NULL DEFAULT 'whatsapp'::text,
  channel text NOT NULL DEFAULT 'whatsapp'::text,
  attempts integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.home_promotion_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  image_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.home_promotion_banners IS 'Imágenes 16:9 del carrusel de promociones en la pantalla de inicio de la tienda.';

CREATE TABLE public.email_otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  email text NOT NULL,
  purpose text NOT NULL CHECK (
    purpose = ANY (ARRAY['signup'::text, 'password_reset'::text])
  ),
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.event_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  event_id uuid NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  ticket_type_id uuid NOT NULL REFERENCES public.event_ticket_types (id) ON DELETE RESTRICT,
  user_id uuid NOT NULL,
  order_id uuid REFERENCES public.orders (id) ON DELETE SET NULL,
  qr_token text NOT NULL UNIQUE,
  people_count integer NOT NULL CHECK (people_count > 0),
  used_people integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active'::text CHECK (
    status = ANY (
      ARRAY[
        'active'::text,
        'completed'::text,
        'cancelled'::text
      ]
    )
  ),
  purchased_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.ticket_benefits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  ticket_id uuid NOT NULL REFERENCES public.event_tickets (id) ON DELETE CASCADE,
  benefit_type text NOT NULL,
  total integer NOT NULL CHECK (total >= 0),
  used integer NOT NULL DEFAULT 0,
  state public.ticket_benefit_state NOT NULL DEFAULT 'blocked'::ticket_benefit_state,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.ticket_action_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  ticket_id uuid NOT NULL REFERENCES public.event_tickets (id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (
    action_type = ANY (ARRAY['entry'::text, 'benefit'::text])
  ),
  benefit_type text,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  actor_user_id uuid,
  action_meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.wallet_accounts (
  user_id uuid PRIMARY KEY,
  balance numeric NOT NULL DEFAULT 0 CHECK (balance >= 0::numeric),
  currency text NOT NULL DEFAULT 'Bs'::text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.wallet_topups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  user_id uuid NOT NULL,
  reference_code text NOT NULL UNIQUE,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  status public.wallet_topup_status NOT NULL DEFAULT 'pending_proof'::wallet_topup_status,
  proof_url text,
  proof_note text,
  reconciliation_hint jsonb NOT NULL DEFAULT '{}'::jsonb,
  approved_by uuid,
  approved_at timestamptz,
  rejected_at timestamptz,
  reject_reason text,
  expires_at timestamptz NOT NULL DEFAULT (now() + '24:00:00'::interval),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  requested_amount numeric,
  verification_delta numeric
);

CREATE TABLE public.wallet_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  user_id uuid NOT NULL,
  direction text NOT NULL CHECK (
    direction = ANY (ARRAY['credit'::text, 'debit'::text])
  ),
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  source_type text NOT NULL,
  source_id text,
  topup_id uuid REFERENCES public.wallet_topups (id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.orders (id) ON DELETE SET NULL,
  event_ticket_type_id uuid REFERENCES public.event_ticket_types (id) ON DELETE SET NULL,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.bank_incoming_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  source text NOT NULL DEFAULT 'tasker_android'::text,
  bank_app text,
  title text,
  body text,
  raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  detected_amount numeric,
  detected_reference text,
  detected_sender text,
  detected_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  match_status text NOT NULL DEFAULT 'unmatched'::text CHECK (
    match_status = ANY (
      ARRAY[
        'unmatched'::text,
        'matched_suggested'::text,
        'matched_confirmed'::text,
        'discarded'::text
      ]
    )
  ),
  matched_topup_id uuid REFERENCES public.wallet_topups (id) ON DELETE SET NULL,
  matched_at timestamptz,
  matched_reference_code text
);

CREATE TABLE public.wallet_webhook_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  label text,
  token_hash text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz
);

CREATE TABLE public.wallet_topup_qr_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  topup_id uuid NOT NULL REFERENCES public.wallet_topups (id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'yape'::text,
  image_url text NOT NULL,
  raw_qr_text text NOT NULL,
  decoded_ok boolean NOT NULL DEFAULT true,
  decoded_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.wallet_qrgen_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  label text,
  token text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  token_hash text NOT NULL
);

CREATE INDEX idx_bank_events_amount ON public.bank_incoming_events USING btree (detected_amount);

CREATE INDEX idx_bank_events_received ON public.bank_incoming_events USING btree (received_at DESC);

CREATE INDEX idx_bank_events_reference ON public.bank_incoming_events USING btree (detected_reference);

CREATE INDEX idx_email_otp_codes_lookup ON public.email_otp_codes USING btree (email, purpose, created_at DESC);

CREATE INDEX idx_event_ticket_types_event ON public.event_ticket_types USING btree (event_id);

CREATE INDEX idx_event_tickets_event ON public.event_tickets USING btree (event_id, purchased_at DESC);

CREATE INDEX idx_event_tickets_user ON public.event_tickets USING btree (user_id, purchased_at DESC);

CREATE INDEX idx_events_starts_at ON public.events USING btree (starts_at);

CREATE INDEX idx_home_promotion_banners_active_sort ON public.home_promotion_banners USING btree (is_active, sort_order);

CREATE INDEX idx_products_event_ticket_type ON public.products USING btree (event_ticket_type_id)
WHERE
  (event_ticket_type_id IS NOT NULL);

CREATE INDEX idx_ticket_benefits_ticket ON public.ticket_benefits USING btree (ticket_id);

CREATE INDEX idx_ticket_logs_ticket_created ON public.ticket_action_logs USING btree (ticket_id, created_at DESC);

CREATE INDEX idx_wallet_ledger_user_created ON public.wallet_ledger USING btree (user_id, created_at DESC);

CREATE INDEX idx_wallet_qrgen_tokens_active ON public.wallet_qrgen_tokens USING btree (is_active, created_at DESC);

CREATE INDEX idx_wallet_topups_status_created ON public.wallet_topups USING btree (status, created_at DESC);

CREATE INDEX idx_wallet_topups_user_created ON public.wallet_topups USING btree (user_id, created_at DESC);

CREATE INDEX idx_wallet_webhook_tokens_active ON public.wallet_webhook_tokens USING btree (is_active, created_at DESC);

CREATE INDEX order_items_order_id_idx ON public.order_items USING btree (order_id);

CREATE INDEX orders_buyer_id_idx ON public.orders USING btree (buyer_id);

CREATE INDEX orders_delivery_status_idx ON public.orders USING btree (delivery_status);

CREATE INDEX orders_driver_id_idx ON public.orders USING btree (driver_id);

CREATE INDEX orders_seller_id_idx ON public.orders USING btree (seller_id);

CREATE UNIQUE INDEX phone_verifications_active_unique_idx ON public.phone_verifications USING btree (phone, channel)
WHERE
  (consumed_at IS NULL);

CREATE INDEX phone_verifications_expires_idx ON public.phone_verifications USING btree (expires_at);

CREATE INDEX phone_verifications_phone_idx ON public.phone_verifications USING btree (phone);

CREATE UNIQUE INDEX profiles_email_unique_idx ON public.profiles USING btree (lower(email))
WHERE
  (email IS NOT NULL);

CREATE UNIQUE INDEX profiles_phone_unique_idx ON public.profiles USING btree (phone)
WHERE
  (phone IS NOT NULL);

CREATE UNIQUE INDEX profiles_username_unique_idx ON public.profiles USING btree (lower(username))
WHERE
  (username IS NOT NULL);

CREATE UNIQUE INDEX reviews_product_id_buyer_id_key ON public.reviews USING btree (product_id, buyer_id);

CREATE UNIQUE INDEX ticket_benefits_ticket_id_benefit_type_key ON public.ticket_benefits USING btree (ticket_id, benefit_type);

CREATE UNIQUE INDEX uq_wallet_ledger_topup_credit ON public.wallet_ledger USING btree (topup_id)
WHERE
  (
    (topup_id IS NOT NULL)
    AND (direction = 'credit'::text)
    AND (source_type = 'topup_approved'::text)
  );

CREATE UNIQUE INDEX uq_wallet_qrgen_tokens_token_hash ON public.wallet_qrgen_tokens USING btree (token_hash);

CREATE UNIQUE INDEX uq_wallet_topup_qr_sources_topup_provider ON public.wallet_topup_qr_sources USING btree (topup_id, provider);

CREATE TRIGGER trg_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at ();

CREATE TRIGGER trg_event_ticket_types_updated_at BEFORE UPDATE ON public.event_ticket_types FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at ();

CREATE TRIGGER trg_event_tickets_updated_at BEFORE UPDATE ON public.event_tickets FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at ();

CREATE TRIGGER orders_set_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW
EXECUTE FUNCTION public.set_orders_updated_at ();

CREATE TRIGGER trg_profiles_delivery_updated_at BEFORE UPDATE ON public.profiles_delivery FOR EACH ROW
EXECUTE FUNCTION public.trg_profiles_delivery_updated_at ();

CREATE TRIGGER trg_profiles_portal_updated_at BEFORE UPDATE ON public.profiles_portal FOR EACH ROW
EXECUTE FUNCTION public.trg_profiles_portal_updated_at ();

CREATE TRIGGER trg_ticket_benefits_updated_at BEFORE UPDATE ON public.ticket_benefits FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at ();

CREATE TRIGGER trg_wallet_accounts_updated_at BEFORE UPDATE ON public.wallet_accounts FOR EACH ROW
EXECUTE FUNCTION public.trg_wallet_accounts_updated_at ();

CREATE TRIGGER trg_wallet_topups_updated_at BEFORE UPDATE ON public.wallet_topups FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at ();

ALTER TABLE public.bank_incoming_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.email_otp_codes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.event_ticket_types ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.event_tickets ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.home_promotion_banners ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.phone_verifications ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles_delivery ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles_portal ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ticket_action_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ticket_benefits ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_accounts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_qrgen_tokens ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_topup_qr_sources ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_topups ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_webhook_tokens ENABLE ROW LEVEL SECURITY;
