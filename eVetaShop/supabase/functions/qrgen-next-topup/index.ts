import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function extractToken(req: Request): string {
  const auth = req.headers.get('authorization') ?? '';
  const raw = auth.trim();
  if (!raw) return '';
  return raw.replace(/^Bearer\s*/i, '').trim().replace(/\s+/g, '');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    const token = extractToken(req);
    if (!token) return json({ error: 'Unauthorized' }, 401);

    const { data: validToken, error: tokenErr } = await supabaseAdmin.rpc('touch_wallet_qrgen_token', {
      p_token: token,
    });
    if (tokenErr || validToken !== true) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const workerId = String(body?.worker_id ?? '').trim();
    const { data, error } = await supabaseAdmin.rpc('claim_next_wallet_topup_for_qrgen', {
      p_worker_id: workerId || null,
    });
    if (error) {
      return json({ error: `No se pudo obtener recarga: ${error.message}` }, 500);
    }

    const rows = Array.isArray(data) ? data : [];
    if (rows.length === 0) {
      return json({ ok: true, has_topup: false, topup: null });
    }

    return json({
      ok: true,
      has_topup: true,
      topup: rows[0],
    });
  } catch (e) {
    return json({ error: `Internal error: ${e}` }, 500);
  }
});
