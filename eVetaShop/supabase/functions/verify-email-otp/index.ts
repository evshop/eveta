import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, normalizeEmail, sha256 } from '../_shared/email_otp.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, code, purpose } = await req.json();
    const normalizedEmail = normalizeEmail(email ?? '');
    const rawCode = String(code ?? '').trim();
    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return json({ error: 'Correo inválido.' }, 400);
    }
    if (!/^\d{6}$/.test(rawCode)) {
      return json({ error: 'El código debe tener 6 dígitos.' }, 400);
    }
    if (purpose !== 'signup' && purpose !== 'password_reset') {
      return json({ error: 'Propósito inválido.' }, 400);
    }

    const { data: otp, error: otpError } = await supabaseAdmin
      .from('email_otp_codes')
      .select('id, code_hash, expires_at, attempts, used_at')
      .eq('email', normalizedEmail)
      .eq('purpose', purpose)
      .is('used_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (otpError) return json({ error: otpError.message }, 500);
    if (!otp) return json({ error: 'No existe un código activo para este correo.' }, 400);

    if (new Date(otp.expires_at).getTime() < Date.now()) {
      return json({ error: 'El código expiró. Solicita uno nuevo.' }, 400);
    }
    if ((otp.attempts ?? 0) >= 5) {
      return json({ error: 'Demasiados intentos. Solicita un nuevo código.' }, 429);
    }

    const codeHash = await sha256(rawCode);
    const isValid = codeHash === otp.code_hash;

    if (!isValid) {
      await supabaseAdmin
        .from('email_otp_codes')
        .update({ attempts: (otp.attempts ?? 0) + 1 })
        .eq('id', otp.id);
      return json({ error: 'Código incorrecto.' }, 400);
    }

    await supabaseAdmin
      .from('email_otp_codes')
      .update({ used_at: new Date().toISOString() })
      .eq('id', otp.id);

    if (purpose === 'signup') {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .maybeSingle();
      if (profile?.id) {
        await supabaseAdmin.auth.admin.updateUserById(profile.id, { email_confirm: true });
      }
      return json({ ok: true });
    }

    const resetToken = crypto.randomUUID();
    const resetHash = await sha256(resetToken);
    const resetExpiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: resetInsertError } = await supabaseAdmin.from('email_otp_codes').insert({
      email: normalizedEmail,
      purpose: 'password_reset',
      code_hash: resetHash,
      expires_at: resetExpiresAt,
      attempts: 0,
    });
    if (resetInsertError) {
      return json({ error: `No se pudo crear token de reset: ${resetInsertError.message}` }, 500);
    }

    return json({ ok: true, reset_token: resetToken });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});
