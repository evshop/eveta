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

function b64ToBytes(b64: string): Uint8Array {
  const binStr = atob(b64);
  const bytes = new Uint8Array(binStr.length);
  for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
  return bytes;
}

function safeExt(contentType: string): string {
  const ct = contentType.toLowerCase();
  if (ct.includes('png')) return 'png';
  if (ct.includes('webp')) return 'webp';
  if (ct.includes('jpeg') || ct.includes('jpg')) return 'jpg';
  return 'bin';
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
  const jwt = (tokenHeader || authHeader.replace(/^Bearer\\s+/i, '')).trim();
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
  const bucket = (body?.bucket ?? 'admin-assets').toString().trim() || 'admin-assets';
  const folder = (body?.folder ?? 'categories').toString().trim() || 'categories';
  const contentType = (body?.content_type ?? '').toString().trim() || 'application/octet-stream';
  const b64 = (body?.base64 ?? '').toString().trim();
  const originalName = (body?.filename ?? '').toString().trim();

  if (!b64) return json({ error: 'Archivo inválido.' }, 400);

  // Ensure bucket exists (public so apps can render images without auth).
  {
    const { data: buckets } = await core.storage.listBuckets();
    const exists = (buckets ?? []).some((b) => b.name === bucket);
    if (!exists) {
      const { error: createErr } = await core.storage.createBucket(bucket, {
        public: true,
        fileSizeLimit: 10 * 1024 * 1024,
      });
      // If it races / already exists, ignore.
      if (createErr && !/already exists/i.test(createErr.message)) {
        return json({ error: createErr.message }, 500);
      }
    }
  }

  const ext = safeExt(contentType);
  const baseName = originalName.replace(/[^a-zA-Z0-9._-]/g, '').slice(-80);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const path = `${folder}/${stamp}-${crypto.randomUUID()}${baseName ? `-${baseName}` : ''}.${ext}`;

  const bytes = b64ToBytes(b64);
  const { error: upErr } = await core.storage.from(bucket).upload(path, bytes, {
    contentType,
    upsert: false,
  });
  if (upErr) return json({ error: upErr.message }, 400);

  const { data: pub } = core.storage.from(bucket).getPublicUrl(path);
  const publicUrl = pub?.publicUrl ?? null;
  if (!publicUrl) return json({ error: 'No se pudo generar URL pública.' }, 500);

  return json({ ok: true, bucket, path, public_url: publicUrl });
});

