import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, normalizeEmail } from '../_shared/email_otp.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// One-time key to run this function (delete after use).
const ONE_TIME_ADMIN_KEY = '9a6f8f0d-0e4f-4d53-9c4a-0a9a66bd1e86';

async function findUserIdByEmail(email: string): Promise<string | null> {
  const perPage = 1000;
  const maxPages = 25;
  for (let page = 1; page <= maxPages; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage });
    if (error || !data?.users?.length) break;
    const u = data.users.find((x) => normalizeEmail(x.email ?? '') === email);
    if (u?.id) return u.id;
    if (data.users.length < perPage) break;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const key = req.headers.get('x-admin-key') ?? '';
    if (key !== ONE_TIME_ADMIN_KEY) {
      return json({ error: 'Forbidden' }, 403);
    }

    const { email, new_password: newPassword } = await req.json();
    const normalizedEmail = normalizeEmail(email ?? '');
    const password = String(newPassword ?? '');

    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return json({ error: 'Correo inválido.' }, 400);
    }
    if (password.length < 6) {
      return json({ error: 'La contraseña debe tener al menos 6 caracteres.' }, 400);
    }

    const userId = await findUserIdByEmail(normalizedEmail);
    if (!userId) {
      return json({ error: 'No existe usuario con ese correo en Auth.' }, 404);
    }

    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      password,
      email_confirm: true,
    });
    if (updateErr) return json({ error: updateErr.message }, 500);

    return json({ ok: true, user_id: userId });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});

