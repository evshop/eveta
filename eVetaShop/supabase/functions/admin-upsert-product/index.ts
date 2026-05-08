import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-admin-access-token',
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

type ProductRow = Record<string, unknown>;

function asArray(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
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

  const tokenHeader = req.headers.get('x-admin-access-token') ?? '';
  const authHeader = req.headers.get('authorization') ?? '';
  const jwt = (tokenHeader || authHeader.replace(/^Bearer\s+/i, '')).trim();
  if (!jwt || jwt.split('.').length !== 3) {
    return json({ error: 'invalid_admin_session' }, 401);
  }

  const email = await portalAuthGetEmail(jwt);
  if (!email) return json({ error: 'invalid_admin_session' }, 401);

  const core = createClient(CORE_URL, CORE_SERVICE_ROLE);

  const { data: adminRow, error: adminErr } = await core
    .from('profiles_portal')
    .select('is_admin, is_active')
    .ilike('email', email)
    .maybeSingle();
  if (adminErr) return json({ error: adminErr.message }, 500);
  if (!adminRow || adminRow.is_admin !== true || adminRow.is_active !== true) {
    return json({ error: 'forbidden' }, 403);
  }

  const body = await req.json().catch(() => ({}));
  const id = (body?.id ?? '').toString().trim();

  const row: ProductRow = {
    seller_id: body?.seller_id ?? null,
    category_id: body?.category_id ?? null,
    name: (body?.name ?? '').toString().trim(),
    description: (body?.description ?? '').toString(),
    price: body?.price ?? null,
    stock: body?.stock ?? null,
    unit: body?.unit ?? null,
    is_active: body?.is_active === true,
    is_featured: body?.is_featured === true,
    images: asArray(body?.images),
    images_layout: asArray(body?.images_layout),
    specs_json: asArray(body?.specs_json),
    tags: asArray(body?.tags),
  };

  if (!(row.name as string)) return json({ error: 'Nombre inválido.' }, 400);

  try {
    if (id) {
      if (!row.seller_id) {
        const { data: existing, error: exErr } = await core
          .from('products')
          .select('seller_id')
          .eq('id', id)
          .maybeSingle();
        if (exErr) return json({ error: exErr.message }, 400);
        row.seller_id = existing?.seller_id ?? null;
      }
      if (!row.seller_id) return json({ error: 'seller_id requerido.' }, 400);
      const { error } = await core.from('products').update(row).eq('id', id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }
    if (!row.seller_id) return json({ error: 'seller_id requerido.' }, 400);
    const { error } = await core.from('products').insert(row);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  } catch (e) {
    return json({ error: `internal_error: ${e}` }, 500);
  }
});

