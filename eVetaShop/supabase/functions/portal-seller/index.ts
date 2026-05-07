import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizeEmail(v: string): string {
  return v.trim().toLowerCase();
}

const CORE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const CORE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const PORTAL_AUTH_URL = Deno.env.get('PORTAL_AUTH_SUPABASE_URL') ?? '';
const PORTAL_AUTH_ANON = Deno.env.get('PORTAL_AUTH_SUPABASE_ANON_KEY') ?? '';

async function portalAuthGetUser(jwt: string): Promise<{ id: string; email: string } | null> {
  const res = await fetch(`${PORTAL_AUTH_URL}/auth/v1/user`, {
    method: 'GET',
    headers: {
      apikey: PORTAL_AUTH_ANON,
      Authorization: `Bearer ${jwt}`,
    },
  });
  if (!res.ok) return null;
  const u = await res.json();
  const id = String(u?.id ?? '').trim();
  const email = normalizeEmail(u?.email ?? '');
  if (!id || !email || !email.includes('@')) return null;
  return { id, email };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!CORE_URL || !CORE_SERVICE_ROLE) {
    return json({ error: 'server_misconfigured_missing_core_env' }, 500);
  }
  if (!PORTAL_AUTH_URL || !PORTAL_AUTH_ANON) {
    return json({ error: 'server_misconfigured_missing_portal_auth_env' }, 500);
  }

  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt.split('.').length !== 3) {
    return json({ error: 'invalid_session' }, 401);
  }

  const authUser = await portalAuthGetUser(jwt);
  if (!authUser) return json({ error: 'invalid_session' }, 401);
  const portalUserId = authUser.id;
  const email = authUser.email;

  const core = createClient(CORE_URL, CORE_SERVICE_ROLE);

  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
  const action = String(body.action ?? '').trim().toLowerCase();

  /// Validación de acceso a la app (sin depender de JWT del Core ni de coincidencia solo por email en Delivery).
  if (action === 'verify_gate') {
    const { data: deliveryRow, error: dErr } = await core
      .from('profiles_delivery')
      .select('id')
      .eq('auth_user_id', portalUserId)
      .maybeSingle();
    if (dErr) return json({ error: dErr.message }, 500);
    if (deliveryRow) return json({ error: 'forbidden_delivery_account' }, 403);

    let { data: portalProfile, error: pErr } = await core
      .from('profiles_portal')
      .select('id, auth_user_id, email, is_admin, is_seller, is_active')
      .eq('auth_user_id', portalUserId)
      .maybeSingle();
    if (pErr) return json({ error: pErr.message }, 500);
    if (!portalProfile) {
      const byEmail = await core
        .from('profiles_portal')
        .select('id, auth_user_id, email, is_admin, is_seller, is_active')
        .ilike('email', email)
        .maybeSingle();
      if (byEmail.error) return json({ error: byEmail.error.message }, 500);
      portalProfile = byEmail.data;
    }
    if (!portalProfile || portalProfile.is_active !== true) {
      return json({ error: 'forbidden_not_portal' }, 403);
    }
    if (portalProfile.is_admin !== true && portalProfile.is_seller !== true) {
      return json({ error: 'forbidden_not_portal' }, 403);
    }
    return json({ ok: true, data: portalProfile });
  }

  const { data: seller, error: sellerErr } = await core
    .from('profiles_portal')
    .select('id, email, is_seller, is_admin, is_active')
    .ilike('email', email)
    .maybeSingle();
  if (sellerErr) return json({ error: sellerErr.message }, 500);
  if (!seller || seller.is_active !== true || (seller.is_seller !== true && seller.is_admin !== true)) {
    return json({ error: 'forbidden_not_seller' }, 403);
  }

  if (action === 'get_store_profile') {
    const { data, error } = await core
      .from('profiles_portal')
      .select(
        'id, auth_user_id, email, full_name, avatar_url, phone, address, username, shop_name, shop_description, shop_logo_url, shop_banner_url, shop_border_color, shop_address, shop_lat, shop_lng, shop_location_photos, is_admin, is_seller, is_active',
      )
      .eq('id', seller.id)
      .maybeSingle();
    if (error) return json({ error: error.message }, 400);
    if (!data) return json({ error: 'not_found' }, 404);
    return json({ ok: true, data });
  }

  if (action === 'update_store_profile') {
    const row: Record<string, unknown> = {
      shop_name: body.shop_name ?? null,
      shop_description: body.shop_description ?? null,
      shop_logo_url: body.shop_logo_url ?? null,
      shop_banner_url: body.shop_banner_url ?? null,
      shop_border_color: body.shop_border_color ?? null,
      shop_address: body.shop_address ?? null,
      shop_lat: body.shop_lat ?? null,
      shop_lng: body.shop_lng ?? null,
      shop_location_photos: Array.isArray(body.shop_location_photos) ? body.shop_location_photos : [],
      is_seller: true,
    };

    const { data, error } = await core
      .from('profiles_portal')
      .update(row)
      .eq('id', seller.id)
      .select('id')
      .maybeSingle();
    if (error) return json({ error: error.message }, 400);
    if (!data) return json({ error: 'not_found' }, 404);
    return json({ ok: true, id: data.id });
  }

  if (action === 'list_orders') {
    const { data, error } = await core
      .from('orders')
      .select(
        'id, status, delivery_status, created_at, buyer_display_name, dropoff_address, subtotal, delivery_fee, total, order_items(id, quantity, total, name_snapshot, image_url)',
      )
      .eq('seller_id', seller.id)
      .order('created_at', { ascending: false });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, data: data ?? [] });
  }

  if (action === 'mark_ready_for_pickup' || action === 'reject_order') {
    const orderId = String(body.order_id ?? '').trim();
    if (!orderId) return json({ error: 'order_id_requerido' }, 400);

    const { data: existing, error: readErr } = await core
      .from('orders')
      .select('id, seller_id, status')
      .eq('id', orderId)
      .eq('seller_id', seller.id)
      .maybeSingle();
    if (readErr) return json({ error: readErr.message }, 400);
    if (!existing) return json({ error: 'not_found' }, 404);

    if (action === 'mark_ready_for_pickup') {
      const { error } = await core
        .from('orders')
        .update({
          status: 'confirmed',
          delivery_status: 'ready_for_pickup',
          updated_at: new Date().toISOString(),
        })
        .eq('id', orderId)
        .eq('seller_id', seller.id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    const { error } = await core
      .from('orders')
      .update({
        status: 'cancelled',
        delivery_status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId)
      .eq('seller_id', seller.id);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: 'action_no_soportada' }, 400);
});

