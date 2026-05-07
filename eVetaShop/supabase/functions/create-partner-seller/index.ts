import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-admin-access-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const CORE_SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const CORE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const PORTAL_AUTH_SUPABASE_URL = Deno.env.get('PORTAL_AUTH_SUPABASE_URL') ?? '';
const PORTAL_AUTH_SUPABASE_ANON_KEY = Deno.env.get('PORTAL_AUTH_SUPABASE_ANON_KEY') ?? '';
const PORTAL_AUTH_SERVICE_ROLE_KEY = Deno.env.get('PORTAL_AUTH_SERVICE_ROLE_KEY') ?? '';

function portalDbClient() {
  if (!PORTAL_AUTH_SUPABASE_URL || !PORTAL_AUTH_SERVICE_ROLE_KEY) return null;
  return createClient(PORTAL_AUTH_SUPABASE_URL, PORTAL_AUTH_SERVICE_ROLE_KEY);
}

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const normalizeEmail = (v: string) => v.trim().toLowerCase();
const looksLikeJwt = (t: string): boolean => !!t && t.split('.').length === 3;

async function portalAuthGetUser(jwt: string): Promise<{ email: string } | null> {
  const res = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/user`, {
    method: 'GET',
    headers: {
      apikey: PORTAL_AUTH_SUPABASE_ANON_KEY,
      Authorization: `Bearer ${jwt}`,
    },
  });
  if (!res.ok) return null;
  const u = await res.json();
  const email = normalizeEmail(u?.email ?? '');
  if (!email || !email.includes('@')) return null;
  return { email };
}

async function portalAuthSignup(email: string, password: string, fullName: string): Promise<string> {
  const res = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: {
      apikey: PORTAL_AUTH_SUPABASE_ANON_KEY,
      Authorization: `Bearer ${PORTAL_AUTH_SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      data: { full_name: fullName, app: 'portal_seller' },
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = payload?.msg ?? payload?.message ?? JSON.stringify(payload);
    throw new Error(`portal_auth_signup_failed: ${msg}`);
  }
  const uid =
    payload?.id?.toString() ??
    payload?.user?.id?.toString() ??
    payload?.data?.user?.id?.toString() ??
    '';
  if (!uid) throw new Error('portal_auth_signup_failed: missing user id');
  return uid;
}

async function portalAuthAdminCreateUser(email: string, password: string, fullName: string): Promise<string> {
  if (!PORTAL_AUTH_SERVICE_ROLE_KEY) {
    throw new Error('portal_auth_admin_create_disabled: missing service role key');
  }
  const res = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: PORTAL_AUTH_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${PORTAL_AUTH_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, app: 'portal_seller' },
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = payload?.msg ?? payload?.message ?? JSON.stringify(payload);
    throw new Error(`portal_auth_admin_create_failed: ${msg}`);
  }
  const uid = payload?.id?.toString() ?? payload?.user?.id?.toString() ?? '';
  if (!uid) throw new Error('portal_auth_admin_create_failed: missing user id');
  return uid;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!CORE_SUPABASE_URL || !CORE_SERVICE_ROLE_KEY) {
    return json({ error: 'server_misconfigured_missing_core_env' }, 500);
  }
  if (!PORTAL_AUTH_SUPABASE_URL || !PORTAL_AUTH_SUPABASE_ANON_KEY) {
    return json({ error: 'server_misconfigured_missing_portal_auth_env' }, 500);
  }

  const coreAdmin = createClient(CORE_SUPABASE_URL, CORE_SERVICE_ROLE_KEY);

  try {
    const rawJson = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const body = (rawJson['body'] && typeof rawJson['body'] === 'object')
      ? (rawJson['body'] as Record<string, unknown>)
      : rawJson;

    const authHeader = req.headers.get('Authorization') ?? '';
    const jwtFromHeader = authHeader.replace(/^Bearer\\s+/i, '').trim();
    const jwtFromCustomHeader = req.headers.get('x-admin-access-token')?.trim() ?? '';
    const jwtFromBody = typeof body['access_token'] === 'string' ? body['access_token'].trim() : '';
    const jwt = [jwtFromBody, jwtFromCustomHeader, jwtFromHeader].find((t) => looksLikeJwt(t)) ?? '';
    if (!jwt) return json({ error: 'invalid_jwt_format' }, 401);

    const adminUser = await portalAuthGetUser(jwt);
    if (!adminUser) return json({ error: 'invalid_admin_session' }, 401);

    const { data: adminRow, error: adminErr } = await coreAdmin
      .from('profiles_portal')
      .select('id, is_admin, is_active')
      .ilike('email', adminUser.email)
      .maybeSingle();
    if (adminErr) return json({ error: `admin_check_failed: ${adminErr.message}` }, 500);
    if (!adminRow || adminRow.is_admin !== true || adminRow.is_active !== true) {
      return json({ error: 'forbidden' }, 403);
    }

    const email = typeof body['email'] === 'string' ? normalizeEmail(body['email']) : '';
    const password = typeof body['password'] === 'string' ? body['password'] : '';
    const fullName = typeof body['full_name'] === 'string' ? body['full_name'].trim() : '';
    const shopName = typeof body['shop_name'] === 'string' ? body['shop_name'].trim() : '';
    const shopDescription = typeof body['shop_description'] === 'string' ? body['shop_description'].trim() : '';

    if (!email || !email.includes('@') || !password || password.length < 6) {
      return json({ error: 'email_y_contraseña_válidos_requeridos_mín_6_caracteres' }, 400);
    }
    if (!fullName || !shopName) {
      return json({ error: 'nombre_y_tienda_requeridos' }, 400);
    }

    let newUserId = '';
    try {
      // Prefer admin create (no emails / no rate limits).
      newUserId = await portalAuthAdminCreateUser(email, password, fullName);
    } catch (_) {
      newUserId = await portalAuthSignup(email, password, fullName);
    }

    // Ensure Portal Auth DB has membership row for the Portal app gate.
    const portalDb = portalDbClient();
    if (portalDb) {
      await portalDb.from('profiles_portal').upsert(
        {
          auth_user_id: newUserId,
          email,
          full_name: fullName,
          shop_name: shopName,
          shop_description: shopDescription,
          is_admin: false,
          is_seller: true,
          is_active: true,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'email' },
      );
    }

    const { error: upsertErr } = await coreAdmin
      .from('profiles_portal')
      .upsert({
        auth_user_id: newUserId,
        email,
        full_name: fullName,
        shop_name: shopName,
        shop_description: shopDescription,
        is_admin: false,
        is_seller: true,
        is_partner_verified: true,
        partner_display_order: 0,
        is_active: true,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'email' });

    if (upsertErr) {
      return json({ error: `profiles_portal_upsert_failed: ${upsertErr.message}` }, 400);
    }

    return json({ ok: true, user_id: newUserId, email }, 200);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'unexpected_error' }, 500);
  }
});