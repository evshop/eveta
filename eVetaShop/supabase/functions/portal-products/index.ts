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

async function portalAuthGetEmail(jwt: string): Promise<string | null> {
  const res = await fetch(`${PORTAL_AUTH_URL}/auth/v1/user`, {
    method: 'GET',
    headers: {
      apikey: PORTAL_AUTH_ANON,
      Authorization: `Bearer ${jwt}`,
    },
  });
  if (!res.ok) return null;
  const u = await res.json();
  const email = normalizeEmail(u?.email ?? '');
  if (!email || !email.includes('@')) return null;
  return email;
}

function pickProductFields(body: Record<string, unknown>): Record<string, unknown> {
  return {
    category_id: body.category_id ?? null,
    name: body.name ?? '',
    description: body.description ?? null,
    price: body.price ?? 0,
    stock: body.stock ?? 0,
    unit: body.unit ?? 'unidad',
    images: Array.isArray(body.images) ? body.images : [],
    is_active: body.is_active === true,
    is_featured: body.is_featured === true,
    specs_json: Array.isArray(body.specs_json) ? body.specs_json : [],
    tags: Array.isArray(body.tags) ? body.tags : [],
  };
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

  const email = await portalAuthGetEmail(jwt);
  if (!email) return json({ error: 'invalid_session' }, 401);

  const core = createClient(CORE_URL, CORE_SERVICE_ROLE);

  const { data: seller, error: sellerErr } = await core
    .from('profiles_portal')
    .select('id, is_seller, is_active')
    .ilike('email', email)
    .maybeSingle();
  if (sellerErr) return json({ error: sellerErr.message }, 500);
  if (!seller || seller.is_active !== true || seller.is_seller !== true) {
    return json({ error: 'forbidden_not_seller' }, 403);
  }

  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
  const action = String(body.action ?? 'list').trim().toLowerCase();

  if (action === 'list_categories') {
    let { data, error } = await core
      .from('categories')
      .select('id, name, parent_id, spec_template_enabled, spec_field_labels, spec_group_title')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });

    // Compatibilidad con esquemas donde categories no tiene is_active/sort_order.
    if (error) {
      const message = error.message.toLowerCase();
      if (message.includes('is_active') || message.includes('sort_order')) {
        const fallback = await core
          .from('categories')
          .select('id, name, parent_id, spec_template_enabled, spec_field_labels, spec_group_title')
          .order('name', { ascending: true });
        data = fallback.data;
        error = fallback.error;
      }
    }

    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, data: data ?? [] });
  }

  if (action === 'list') {
    const { data, error } = await core
      .from('products')
      .select(
        'id, name, price, stock, images, category_id, description, unit, tags, specs_json, is_active, is_featured, event_ticket_type_id',
      )
      .eq('seller_id', seller.id)
      .order('created_at', { ascending: false });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, data: data ?? [] });
  }

  if (action === 'get') {
    const id = String(body.id ?? '').trim();
    if (!id) return json({ error: 'id_requerido' }, 400);
    const { data, error } = await core
      .from('products')
      .select(
        'id, name, price, stock, images, category_id, description, unit, tags, specs_json, is_active, is_featured, event_ticket_type_id',
      )
      .eq('id', id)
      .eq('seller_id', seller.id)
      .maybeSingle();
    if (error) return json({ error: error.message }, 400);
    if (!data) return json({ error: 'not_found' }, 404);
    return json({ ok: true, data });
  }

  if (action === 'upsert') {
    const id = String(body.id ?? '').trim();
    const row = {
      ...pickProductFields(body),
      seller_id: seller.id,
    };
    if (!String(row.name ?? '').trim()) return json({ error: 'nombre_invalido' }, 400);

    if (id) {
      const { data, error } = await core
        .from('products')
        .update(row)
        .eq('id', id)
        .eq('seller_id', seller.id)
        .select('id')
        .maybeSingle();
      if (error) return json({ error: error.message }, 400);
      if (!data) return json({ error: 'not_found' }, 404);
      return json({ ok: true, id: data.id });
    }

    const { data, error } = await core.from('products').insert(row).select('id').single();
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, id: data.id });
  }

  if (action === 'delete') {
    const id = String(body.id ?? '').trim();
    if (!id) return json({ error: 'id_requerido' }, 400);
    const { error } = await core.from('products').delete().eq('id', id).eq('seller_id', seller.id);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: 'action_no_soportada' }, 400);
});

