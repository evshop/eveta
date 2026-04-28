import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const TASKER_WEBHOOK_SECRET = Deno.env.get('TASKER_WEBHOOK_SECRET') ?? '';

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

function extractWebhookToken(req: Request): string {
  const auth = req.headers.get('authorization') ?? '';
  const altA = req.headers.get('x-webhook-token') ?? '';
  const altB = req.headers.get('x-tasker-token') ?? '';
  const raw = (auth || altA || altB).trim();
  if (!raw) return '';

  // Acepta:
  // - "Bearer <token>"
  // - "Bearer<token>" (sin espacio, algunos clientes lo envían así)
  // - "<token>" directo
  const withoutBearer = raw.replace(/^Bearer\s*/i, '').trim();
  // Limpia comillas/saltos invisibles de copy-paste.
  return withoutBearer.replace(/^["']+|["']+$/g, '').replace(/\s+/g, '');
}

function parseAmount(text: string): number | null {
  const normalized = text.replace(',', '.');
  const m = normalized.match(/(?:bs\.?\s*)?(\d+(?:\.\d{1,2})?)/i);
  if (!m) return null;
  const n = Number.parseFloat(m[1]);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.round(n * 100) / 100;
}

function parseReference(text: string): string | null {
  const m = text.toUpperCase().match(/WLT-[A-Z0-9]{6,20}/);
  return m ? m[0] : null;
}

function parseDetectedAt(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const raw = String(value).trim();
  if (!raw) return null;

  // Epoch en segundos o milisegundos.
  if (/^\d+$/.test(raw)) {
    const n = Number(raw);
    if (!Number.isFinite(n)) return null;
    const ms = raw.length <= 10 ? n * 1000 : n;
    const d = new Date(ms);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }

  // ISO u otro parseable por Date.
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const token = extractWebhookToken(req);
  let tokenOk = false;
  if (TASKER_WEBHOOK_SECRET && token === TASKER_WEBHOOK_SECRET) {
    tokenOk = true;
  } else {
    const { data: validToken, error: tokenErr } = await supabaseAdmin.rpc('touch_wallet_webhook_token', {
      p_token: token,
    });
    if (!tokenErr && validToken === true) {
      tokenOk = true;
    }
  }
  if (!tokenOk) {
    return json({ error: 'Unauthorized' }, 401);
  }

  try {
    const payload = await req.json();
    const title = String(payload?.title ?? '').trim();
    const body = String(payload?.text ?? payload?.body ?? '').trim();
    const app = String(payload?.app ?? payload?.package ?? '').trim();
    const sender = String(payload?.sender ?? '').trim();
    const detectedAt = parseDetectedAt(payload?.timestamp ?? payload?.detected_at);
    const merged = `${title} ${body}`.trim();

    const detectedAmount = parseAmount(merged);
    const detectedReference = parseReference(merged);

    const { data: inserted, error: insertErr } = await supabaseAdmin
      .from('bank_incoming_events')
      .insert({
        source: 'tasker_android',
        bank_app: app || null,
        title: title || null,
        body: body || null,
        raw_payload: payload ?? {},
        detected_amount: detectedAmount,
        detected_reference: detectedReference,
        detected_sender: sender || null,
        detected_at: detectedAt,
      })
      .select('id')
      .single();

    if (insertErr) {
      return json({ error: `Insert failed: ${insertErr.message}` }, 500);
    }

    // Matching asistido (usa role service + check admin en SQL no aplica aquí).
    // Ejecutamos por RPC interno sin depender de sesión auth.uid.
    const eventId = inserted.id as string;
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { error: matchErr } = await supabaseAdmin.rpc('match_wallet_topups_with_bank_event', {
      p_event_id: eventId,
    });

    return json({
      ok: true,
      event_id: eventId,
      detected_amount: detectedAmount,
      detected_reference: detectedReference,
      match_attempted: !matchErr,
      match_error: matchErr?.message ?? null,
    });
  } catch (e) {
    return json({ error: `Internal error: ${e}` }, 500);
  }
});
