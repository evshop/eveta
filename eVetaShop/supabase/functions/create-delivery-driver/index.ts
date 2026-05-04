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
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: 'Faltan secrets SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY.' }, 500);
    }
    if (!SUPABASE_ANON_KEY) {
      return json({ error: 'Falta SUPABASE_ANON_KEY en secrets.' }, 500);
    }

    const authHeader = req.headers.get('authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token || token.split('.').length !== 3) {
      return json({ error: 'JWT inválido. Inicia sesión como admin e intenta de nuevo.' }, 401);
    }

    const body = await req.json();
    const email = normalizeEmail(body?.email ?? '');
    const password = (body?.password ?? '').toString();
    const fullName = (body?.full_name ?? '').toString().trim();

    if (!email || !email.includes('@')) return json({ error: 'Correo inválido.' }, 400);
    if (!password || password.length < 6) return json({ error: 'Contraseña inválida (mín. 6).' }, 400);
    if (!fullName) return json({ error: 'Nombre vacío.' }, 400);

    // Validar admin usando el JWT del usuario (RLS / auth.uid()).
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: isAdmin, error: adminErr } = await supabaseUser.rpc('profile_is_admin');
    if (adminErr) return json({ error: `No se pudo validar admin: ${adminErr.message}` }, 403);
    if (isAdmin !== true) return json({ error: 'Sin permisos de administrador.' }, 403);

    // Crear usuario en Auth.
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        app: 'delivery',
      },
    });
    if (createErr) return json({ error: `No se pudo crear auth user: ${createErr.message}` }, 400);
    const userId = created.user?.id;
    if (!userId) return json({ error: 'Respuesta inesperada al crear usuario.' }, 500);

    // Estricto: delivery no vive en profiles. Borra fila auto-creada por triggers si la hubiera.
    await supabaseAdmin.from('profiles').delete().eq('id', userId).catch(() => {});

    const { data: deliveryRow, error: profErr } = await supabaseAdmin
      .from('profiles_delivery')
      .insert({
        auth_user_id: userId,
        email,
        full_name: fullName,
        is_active: true,
      })
      .select('id')
      .single();
    if (profErr || !deliveryRow?.id) {
      await supabaseAdmin.auth.admin.deleteUser(userId).catch(() => {});
      return json(
        { error: `No se pudo crear profiles_delivery: ${profErr?.message ?? 'unknown'}` },
        400,
      );
    }

    return json({
      ok: true,
      user_id: userId,
      delivery_profile_id: deliveryRow.id,
      email,
    });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});

