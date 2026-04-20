import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6.9.15';
import {
  corsHeaders,
  generateSixDigitCode,
  json,
  normalizeEmail,
  purposeLabel,
  sha256,
} from '../_shared/email_otp.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_APP_PASSWORD = Deno.env.get('GMAIL_APP_PASSWORD') ?? '';

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, purpose, require_portal_access: requirePortalAccess } = await req.json();
    const normalizedEmail = normalizeEmail(email ?? '');
    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return json({ error: 'Correo inválido.' }, 400);
    }
    if (purpose !== 'signup' && purpose !== 'password_reset') {
      return json({ error: 'Propósito inválido.' }, 400);
    }
    if (purpose === 'password_reset' && requirePortalAccess === true) {
      const { data: portalProfile, error: portalErr } = await supabaseAdmin
        .from('profiles')
        .select('is_admin, is_seller')
        .ilike('email', normalizedEmail)
        .maybeSingle();
      if (portalErr) {
        return json({ error: `No se pudo validar el acceso al portal: ${portalErr.message}` }, 500);
      }
      if (portalProfile == null) {
        return json({ error: 'No existe una cuenta con ese correo en el portal.' }, 400);
      }
      const ok =
        portalProfile.is_admin === true || portalProfile.is_seller === true;
      if (!ok) {
        return json({ error: 'Ese correo no tiene acceso al portal.' }, 403);
      }
    }
    if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
      return json({ error: 'Faltan secrets de Gmail en Supabase.' }, 500);
    }

    const code = generateSixDigitCode();
    const codeHash = await sha256(code);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: insertError } = await supabaseAdmin.from('email_otp_codes').insert({
      email: normalizedEmail,
      purpose,
      code_hash: codeHash,
      expires_at: expiresAt,
      attempts: 0,
    });
    if (insertError) {
      return json({ error: `No se pudo guardar OTP: ${insertError.message}` }, 500);
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: GMAIL_USER,
        pass: GMAIL_APP_PASSWORD,
      },
    });

    await transporter.sendMail({
      from: `"eVeta Verificacion" <${GMAIL_USER}>`,
      to: normalizedEmail,
      subject: 'Tu codigo de verificacion eVeta',
      text:
          `Tu codigo de verificacion es: ${code}\n\n` +
          `Este codigo vence en 10 minutos.\n` +
          `Usalo para ${purposeLabel(purpose)}.\n\n` +
          `Si no solicitaste este codigo, ignora este correo.`,
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.4;color:#111">
          <h2>Codigo de verificacion eVeta</h2>
          <p>Usa este codigo para <b>${purposeLabel(purpose)}</b>:</p>
          <p style="font-size:30px;font-weight:700;letter-spacing:4px">${code}</p>
          <p>Este codigo vence en <b>10 minutos</b>.</p>
          <p>Si no solicitaste este codigo, ignora este correo.</p>
        </div>
      `,
    });

    return json({ ok: true });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});
