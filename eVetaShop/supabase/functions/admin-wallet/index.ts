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

async function assertAdmin(core: ReturnType<typeof createClient>, email: string): Promise<boolean> {
  const { data: adminRow, error: adminErr } = await core
    .from('profiles_portal')
    .select('is_admin, is_active')
    .ilike('email', email)
    .maybeSingle();
  if (adminErr) return false;
  return adminRow?.is_admin === true && adminRow?.is_active === true;
}

type Action =
  | 'list_webhook_tokens'
  | 'create_webhook_token'
  | 'revoke_webhook_token'
  | 'list_qrgen_tokens'
  | 'create_qrgen_token'
  | 'revoke_qrgen_token'
  | 'list_bank_events'
  | 'approve_topup'
  | 'reject_topup'
  | 'retry_match_bank_event';

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
  const ok = await assertAdmin(core, email);
  if (!ok) return json({ error: 'forbidden' }, 403);

  const body = await req.json().catch(() => ({}));
  const action = (body?.action ?? '').toString().trim() as Action;

  try {
    switch (action) {
      case 'list_webhook_tokens': {
        const rows = await core.rpc('list_wallet_webhook_tokens');
        return json({ ok: true, data: rows ?? [] });
      }
      case 'create_webhook_token': {
        const label = body?.label ?? null;
        const rows = await core.rpc('create_wallet_webhook_token', { p_label: label });
        const list = Array.isArray(rows) ? rows : [];
        return json({ ok: true, data: list[0] ?? null });
      }
      case 'revoke_webhook_token': {
        const id = (body?.token_id ?? '').toString().trim();
        if (!id) return json({ error: 'token_id inválido' }, 400);
        await core.rpc('revoke_wallet_webhook_token', { p_token_id: id });
        return json({ ok: true });
      }
      case 'list_qrgen_tokens': {
        const rows = await core.rpc('list_wallet_qrgen_tokens');
        return json({ ok: true, data: rows ?? [] });
      }
      case 'create_qrgen_token': {
        const label = body?.label ?? null;
        const rows = await core.rpc('create_wallet_qrgen_token', { p_label: label });
        const list = Array.isArray(rows) ? rows : [];
        return json({ ok: true, data: list[0] ?? null });
      }
      case 'revoke_qrgen_token': {
        const id = (body?.token_id ?? '').toString().trim();
        if (!id) return json({ error: 'token_id inválido' }, 400);
        await core.rpc('revoke_wallet_qrgen_token', { p_token_id: id });
        return json({ ok: true });
      }
      case 'list_bank_events': {
        const limit = Number(body?.limit ?? 80);
        const { data, error } = await core
          .from('bank_incoming_events')
          .select(
            'id, source, bank_app, title, body, detected_amount, detected_reference, detected_sender, detected_at, received_at, match_status, matched_topup_id, matched_reference_code, raw_payload, wallet_topups(reference_code)',
          )
          .order('received_at', { ascending: false })
          .limit(Number.isFinite(limit) ? Math.max(1, Math.min(200, limit)) : 80);
        if (error) return json({ error: error.message }, 400);
        return json({ ok: true, data: data ?? [] });
      }
      case 'approve_topup': {
        const topupId = (body?.topup_id ?? '').toString().trim();
        const eventId = body?.event_id ?? null;
        if (!topupId) return json({ error: 'topup_id inválido' }, 400);
        await core.rpc('confirm_wallet_topup_match_and_approve', {
          p_topup_id: topupId,
          p_event_id: eventId,
        });
        return json({ ok: true });
      }
      case 'reject_topup': {
        const topupId = (body?.topup_id ?? '').toString().trim();
        const reason = body?.reason ?? null;
        if (!topupId) return json({ error: 'topup_id inválido' }, 400);
        await core.rpc('reject_wallet_topup', { p_topup_id: topupId, p_reason: reason });
        return json({ ok: true });
      }
      case 'retry_match_bank_event': {
        const eventId = (body?.event_id ?? '').toString().trim();
        if (!eventId) return json({ error: 'event_id inválido' }, 400);
        const rows = await core.rpc('admin_retry_match_bank_event', { p_event_id: eventId });
        return json({ ok: true, data: rows ?? [] });
      }
      default:
        return json({ error: 'action inválida' }, 400);
    }
  } catch (e) {
    return json({ error: `internal_error: ${e}` }, 500);
  }
});

