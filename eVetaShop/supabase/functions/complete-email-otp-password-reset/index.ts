import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, normalizeEmail, sha256 } from '../_shared/email_otp.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/** Busca el id de Auth por correo: primero profiles, luego auth.users (cuenta sin fila en profiles). */
async function findAuthUserIdByEmail(email: string): Promise<string | null> {
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .ilike('email', email)
    .maybeSingle();
  if (profile?.id) return profile.id as string;

  const { data: page, error } = await supabaseAdmin.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (error) {
    console.error('auth.admin.listUsers', error);
    return null;
  }
  const u = page.users.find((x) => x.email?.toLowerCase() === email.toLowerCase());
  return u?.id ?? null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, reset_token: resetToken, new_password: newPassword } = await req.json();
    const normalizedEmail = normalizeEmail(email ?? '');
    const token = String(resetToken ?? '').trim();
    const password = String(newPassword ?? '');

    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return json({ error: 'Correo inválido.' }, 400);
    }
    if (!token) {
      return json({ error: 'Token inválido.' }, 400);
    }
    if (password.length < 6) {
      return json({ error: 'La contraseña debe tener al menos 6 caracteres.' }, 400);
    }

    const tokenHash = await sha256(token);
    const { data: tokenRow, error: tokenError } = await supabaseAdmin
      .from('email_otp_codes')
      .select('id, expires_at, used_at')
      .eq('email', normalizedEmail)
      .eq('purpose', 'password_reset')
      .eq('code_hash', tokenHash)
      .maybeSingle();
    if (tokenError) return json({ error: tokenError.message }, 500);
    if (!tokenRow || tokenRow.used_at != null) {
      return json({ error: 'Token inválido o ya utilizado.' }, 400);
    }
    if (new Date(tokenRow.expires_at).getTime() < Date.now()) {
      return json({ error: 'Token expirado.' }, 400);
    }

    const userId = await findAuthUserIdByEmail(normalizedEmail);
    if (!userId) {
      return json(
        {
          error:
            'No hay una cuenta registrada con ese correo. Verifica el correo o crea una cuenta nueva.',
        },
        404,
      );
    }

    const { error: updateUserError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      password,
    });
    if (updateUserError) {
      return json({ error: updateUserError.message }, 500);
    }

    await supabaseAdmin
      .from('email_otp_codes')
      .update({ used_at: new Date().toISOString() })
      .eq('id', tokenRow.id);

    return json({ ok: true });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});
