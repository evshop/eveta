import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-admin-access-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function toDeliveryAuthEmail(value: string): string {
  const e = normalizeEmail(value);
  const at = e.indexOf('@');
  if (at <= 0 || at === e.length - 1) return e;
  const local = e.slice(0, at);
  const domain = e.slice(at + 1);
  const baseLocal = local.includes('+') ? local.split('+')[0] : local;
  return `${baseLocal}+delivery@${domain}`;
}

function isDuplicateAuthEmailError(msg: string): boolean {
  const m = msg.toLowerCase();
  return (
    m.includes('already been registered') ||
    m.includes('already registered') ||
    m.includes('user already registered') ||
    m.includes('duplicate') && m.includes('email')
  );
}

/** Busca `auth.users.id` por email (listUsers paginado; OK para volúmenes típicos de admin). */
async function findAuthUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  const target = normalizeEmail(email);
  for (let page = 1; page <= 25; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) return null;
    const users = data?.users ?? [];
    for (const u of users) {
      if (normalizeEmail(u.email ?? '') === target) return u.id;
    }
    if (users.length < 200) break;
  }
  return null;
}

const CORE_SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const CORE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const PORTAL_AUTH_SUPABASE_URL = Deno.env.get('PORTAL_AUTH_SUPABASE_URL') ?? '';
const PORTAL_AUTH_SUPABASE_ANON_KEY = Deno.env.get('PORTAL_AUTH_SUPABASE_ANON_KEY') ?? '';
const PORTAL_AUTH_SERVICE_ROLE_KEY = Deno.env.get('PORTAL_AUTH_SERVICE_ROLE_KEY') ?? '';

function portalDbClient() {
  if (!PORTAL_AUTH_SUPABASE_URL || !PORTAL_AUTH_SERVICE_ROLE_KEY) return null;
  return createClient(PORTAL_AUTH_SUPABASE_URL, PORTAL_AUTH_SERVICE_ROLE_KEY);
}

const coreAdmin = createClient(CORE_SUPABASE_URL, CORE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    if (!CORE_SUPABASE_URL || !CORE_SERVICE_ROLE_KEY) {
      return json({ error: 'Faltan secrets CORE SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY.' }, 500);
    }
    if (!PORTAL_AUTH_SUPABASE_URL || !PORTAL_AUTH_SUPABASE_ANON_KEY) {
      return json({ error: 'Falta PORTAL_AUTH_SUPABASE_URL/ANON_KEY en secrets.' }, 500);
    }

    const authHeader = req.headers.get('authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token || token.split('.').length !== 3) {
      return json({ error: 'JWT inválido. Inicia sesión como admin e intenta de nuevo.' }, 401);
    }

    const body = await req.json();
    const baseEmail = normalizeEmail(body?.email ?? '');
    const email = toDeliveryAuthEmail(baseEmail);
    const password = (body?.password ?? '').toString();
    const fullName = (body?.full_name ?? '').toString().trim();

    if (!baseEmail || !baseEmail.includes('@')) return json({ error: 'Correo inválido.' }, 400);
    if (!password || password.length < 6) return json({ error: 'Contraseña inválida (mín. 6).' }, 400);
    if (!fullName) return json({ error: 'Nombre vacío.' }, 400);

    const meRes = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/user`, {
      method: 'GET',
      headers: {
        apikey: PORTAL_AUTH_SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
      },
    });
    if (!meRes.ok) return json({ error: 'invalid_admin_session' }, 401);
    const me = await meRes.json();
    const adminEmail = normalizeEmail(me?.email ?? '');
    if (!adminEmail || !adminEmail.includes('@')) return json({ error: 'invalid_admin_session' }, 401);
    const { data: adminRow, error: adminErr } = await coreAdmin
      .from('profiles_portal')
      .select('id, is_admin, is_active')
      .ilike('email', adminEmail)
      .maybeSingle();
    if (adminErr) return json({ error: `No se pudo validar admin: ${adminErr.message}` }, 403);
    if (!adminRow || adminRow.is_admin !== true || adminRow.is_active !== true) {
      return json({ error: 'Sin permisos de administrador.' }, 403);
    }

    let userId = '';
    if (PORTAL_AUTH_SERVICE_ROLE_KEY) {
      const adminRes = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/admin/users`, {
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
          user_metadata: { full_name: fullName, app: 'delivery' },
        }),
      });
      const payload = await adminRes.json().catch(() => ({}));
      if (adminRes.ok) {
        userId = payload?.id?.toString() ?? payload?.user?.id?.toString() ?? '';
      }
    }
    if (!userId) {
      // Fallback: signup (may hit email rate limit).
      const signupRes = await fetch(`${PORTAL_AUTH_SUPABASE_URL}/auth/v1/signup`, {
        method: 'POST',
        headers: {
          apikey: PORTAL_AUTH_SUPABASE_ANON_KEY,
          Authorization: `Bearer ${PORTAL_AUTH_SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          password,
          data: { full_name: fullName, app: 'delivery' },
        }),
      });
      const signupPayload = await signupRes.json().catch(() => ({}));
      if (!signupRes.ok) {
        const msg = signupPayload?.msg ?? signupPayload?.message ?? JSON.stringify(signupPayload);
        return json({ error: `portal_auth_signup_failed: ${msg}` }, 400);
      }
      userId = signupPayload?.id?.toString() ?? signupPayload?.user?.id?.toString() ?? '';
      if (!userId) return json({ error: 'portal_auth_signup_failed: missing user id' }, 500);
    }
    const linkedExistingAuth = false;

    // Ensure Portal Auth DB has delivery membership row for portal/admin gate checks.
    const portalDb = portalDbClient();
    if (portalDb) {
      await portalDb.from('profiles_delivery').upsert(
        {
          auth_user_id: userId,
          email: baseEmail,
          full_name: fullName,
          is_active: true,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'email' },
      );
    }

    const { data: deliveryRow, error: profErr } = await coreAdmin
      .from('profiles_delivery')
      .insert({
        auth_user_id: userId,
        email: baseEmail,
        full_name: fullName,
        is_active: true,
      })
      .select('id')
      .single();

    if (profErr || !deliveryRow?.id) {
      return json(
        { error: `No se pudo crear profiles_delivery: ${profErr?.message ?? 'unknown'}` },
        400,
      );
    }

    return json({
      ok: true,
      user_id: userId,
      delivery_profile_id: deliveryRow.id,
      email: baseEmail,
      auth_email: email,
      ...(linkedExistingAuth ? { linked_existing_auth: true } : {}),
    });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});
