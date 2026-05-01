import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const TEMP_BUCKET = 'wallet-qr-temp';

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

function decodeJwtSub(authHeader: string): string | null {
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(atob(parts[1]));
    const sub = String(payload?.sub ?? '').trim();
    return sub || null;
  } catch {
    return null;
  }
}

function extractToken(req: Request): string {
  const auth = req.headers.get('authorization') ?? '';
  const raw = auth.trim();
  if (!raw) return '';
  return raw.replace(/^Bearer\s*/i, '').trim().replace(/\s+/g, '');
}

async function decodeQrFromImageUrl(imageUrl: string): Promise<string | null> {
  const endpoint = `https://api.qrserver.com/v1/read-qr-code/?fileurl=${encodeURIComponent(imageUrl)}`;
  const resp = await fetch(endpoint);
  if (!resp.ok) return null;
  const data = await resp.json();
  if (!Array.isArray(data) || data.length === 0) return null;
  const first = data[0];
  const symbol = Array.isArray(first?.symbol) ? first.symbol[0] : null;
  const raw = typeof symbol?.data === 'string' ? symbol.data.trim() : '';
  if (!raw || raw.toLowerCase() === 'null') return null;
  return raw;
}

async function decodeQrFromBytes(bytes: Uint8Array, fileName: string, mimeType: string): Promise<string | null> {
  const endpoint = 'https://api.qrserver.com/v1/read-qr-code/';
  const form = new FormData();
  // Asegura ArrayBuffer (evita tipos SharedArrayBuffer en TS tooling).
  // TS tooling puede inferir SharedArrayBuffer; casteo para evitar falsos positivos.
  const ab = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as unknown as ArrayBuffer;
  form.append('file', new File([ab], fileName || 'qr.png', { type: mimeType || 'image/png' }));
  const resp = await fetch(endpoint, { method: 'POST', body: form });
  if (!resp.ok) return null;
  const data = await resp.json();
  if (!Array.isArray(data) || data.length === 0) return null;
  const first = data[0];
  const symbol = Array.isArray(first?.symbol) ? first.symbol[0] : null;
  const raw = typeof symbol?.data === 'string' ? symbol.data.trim() : '';
  if (!raw || raw.toLowerCase() === 'null') return null;
  return raw;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const auth = req.headers.get('authorization') ?? '';
  const userId = decodeJwtSub(auth);

  let tempPath: string | null = null;
  try {
    let allowed = false;
    if (userId) {
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: auth } },
      });
      const { data: isAdmin, error: adminErr } = await userClient.rpc('profile_is_admin');
      if (!adminErr && isAdmin === true) {
        allowed = true;
      }
    }
    if (!allowed) {
      const token = extractToken(req);
      if (token) {
        const { data: validToken, error: tokenErr } = await supabaseAdmin.rpc('touch_wallet_qrgen_token', {
          p_token: token,
        });
        if (!tokenErr && validToken === true) {
          allowed = true;
        }
      }
    }
    if (!allowed) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const contentType = req.headers.get('content-type') ?? '';
    let topupId = '';
    let provider = 'yape';
    let fileName = 'qr.png';
    let mimeType = 'image/png';
    let bytes: Uint8Array | null = null;

    if (contentType.toLowerCase().includes('multipart/form-data')) {
      const form = await req.formData();
      topupId = String(form.get('topup_id') ?? '').trim();
      provider = String(form.get('provider') ?? 'yape').trim().toLowerCase();
      const f = form.get('file');
      if (!(f instanceof File)) {
        return json({ error: 'file es requerido (multipart/form-data).' }, 400);
      }
      fileName = (f.name || 'qr.png').trim();
      mimeType = (f.type || 'image/png').trim();
      bytes = new Uint8Array(await f.arrayBuffer());
    } else {
      const body = await req.json();
      topupId = String(body?.topup_id ?? '').trim();
      provider = String(body?.provider ?? 'yape').trim().toLowerCase();
      fileName = String(body?.file_name ?? 'qr.png').trim();
      mimeType = String(body?.mime_type ?? 'image/png').trim();
      const fileBase64 = String(body?.file_base64 ?? '').trim();
      if (fileBase64) {
        bytes = Uint8Array.from(atob(fileBase64), (c) => c.charCodeAt(0));
      }
    }

    if (!topupId || !bytes || bytes.length === 0) {
      return json({ error: 'topup_id y archivo son requeridos.' }, 400);
    }

    // Decodifica desde bytes directamente (más confiable que fileurl).
    const rawQr = await decodeQrFromBytes(bytes, fileName, mimeType);
    if (!rawQr) {
      return json({ error: 'No se pudo decodificar QR desde la imagen.' }, 422);
    }

    const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    tempPath = `${topupId}/${Date.now()}_${safeName}`;

    const { error: upErr } = await supabaseAdmin.storage
      .from(TEMP_BUCKET)
      .upload(tempPath, bytes, {
        contentType: mimeType,
        upsert: true,
      });
    if (upErr) {
      return json({ error: `No se pudo subir imagen temporal: ${upErr.message}` }, 500);
    }

    const { data: signed, error: signedErr } = await supabaseAdmin.storage
      .from(TEMP_BUCKET)
      .createSignedUrl(tempPath, 60);
    if (signedErr || !signed?.signedUrl) {
      return json({ error: `No se pudo firmar URL temporal: ${signedErr?.message ?? 'unknown'}` }, 500);
    }

    const signedUrl = signed.signedUrl;

    const { data: saved, error: saveErr } = await supabaseAdmin.rpc('store_wallet_topup_qr_source', {
      p_topup_id: topupId,
      p_provider: provider,
      p_image_url: signedUrl,
      p_raw_qr_text: rawQr,
      p_decoded_ok: true,
    });
    if (saveErr) {
      return json({ error: `No se pudo guardar QR: ${saveErr.message}` }, 500);
    }

    return json({
      ok: true,
      topup_id: topupId,
      provider,
      raw_qr_text: rawQr,
      saved,
      temp_deleted: true,
    });
  } catch (e) {
    return json({ error: `Internal error: ${e}` }, 500);
  } finally {
    if (tempPath) {
      await supabaseAdmin.storage.from(TEMP_BUCKET).remove([tempPath]);
    }
  }
});
