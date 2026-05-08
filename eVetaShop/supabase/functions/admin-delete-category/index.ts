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
  const deleteAll = body?.delete_all === true;
  if (!id && !deleteAll) return json({ error: 'ID inválido.' }, 400);

  try {
    if (deleteAll) {
      // Best-effort: borra primero subcategorías, luego padres.
      await core.from('categories').delete().not('parent_id', 'is', null);
      await core.from('categories').delete().is('parent_id', null);
      return json({ ok: true });
    }

    // Borra subcategorías de este nodo (si existen) y luego la fila.
    await core.from('categories').delete().eq('parent_id', id);
    const { error: delErr } = await core.from('categories').delete().eq('id', id);
    if (delErr) return json({ error: delErr.message }, 400);
    return json({ ok: true });
  } catch (e) {
    return json({ error: `internal_error: ${e}` }, 500);
  }
});

