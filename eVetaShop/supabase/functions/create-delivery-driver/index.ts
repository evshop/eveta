import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

function isDuplicateAuthEmailError(msg: string): boolean {
  const m = msg.toLowerCase();
  return (
    m.includes('already been registered') ||
    m.includes('already registered') ||
    m.includes('user already registered') ||
    m.includes('duplicate') && m.includes('email')
  );
}

/** Busca `auth.users.id` por email (listUsers paginado; OK para volúmenes típicos de admin). */
async function findAuthUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  const target = normalizeEmail(email);
  for (let page = 1; page <= 25; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) return null;
    const users = data?.users ?? [];
    for (const u of users) {
      if (normalizeEmail(u.email ?? '') === target) return u.id;
    }
    if (users.length < 200) break;
  }
  return null;
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

    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: isAdmin, error: adminErr } = await supabaseUser.rpc('profile_is_admin');
    if (adminErr) return json({ error: `No se pudo validar admin: ${adminErr.message}` }, 403);
    if (isAdmin !== true) return json({ error: 'Sin permisos de administrador.' }, 403);

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        app: 'delivery',
      },
    });

    let userId: string | null = created.user?.id ?? null;
    let linkedExistingAuth = false;

    if (createErr) {
      const errMsg = createErr.message ?? '';
      if (!isDuplicateAuthEmailError(errMsg)) {
        return json({ error: `No se pudo crear auth user: ${errMsg}` }, 400);
      }
      userId = await findAuthUserIdByEmail(supabaseAdmin, email);
      if (!userId) {
        return json({ error: `No se pudo crear auth user: ${errMsg}` }, 400);
      }
      linkedExistingAuth = true;

      const { data: portalRow } = await supabaseAdmin
        .from('profiles_portal')
        .select('id')
        .eq('auth_user_id', userId)
        .maybeSingle();
      if (portalRow?.id) {
        return json(
          {
            error:
              'Este correo ya pertenece a una cuenta Portal/Tienda. Delivery debe usar un correo distinto o un usuario que no sea vendedor Portal.',
          },
          400,
        );
      }

      const { data: existingDelivery } = await supabaseAdmin
        .from('profiles_delivery')
        .select('id')
        .eq('auth_user_id', userId)
        .maybeSingle();
      if (existingDelivery?.id) {
        return json({
          ok: true,
          user_id: userId,
          delivery_profile_id: existingDelivery.id,
          email,
          already_delivery: true,
        });
      }

      const { error: upErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        password,
        user_metadata: {
          full_name: fullName,
          app: 'delivery',
        },
      });
      if (upErr) {
        return json({ error: `No se pudo actualizar el usuario existente: ${upErr.message}` }, 400);
      }
    } else {
      if (!userId) return json({ error: 'Respuesta inesperada al crear usuario.' }, 500);
      await supabaseAdmin.from('profiles').delete().eq('id', userId).catch(() => {});
    }

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
      if (!linkedExistingAuth && userId) {
        await supabaseAdmin.auth.admin.deleteUser(userId).catch(() => {});
      }
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
      ...(linkedExistingAuth ? { linked_existing_auth: true } : {}),
    });
  } catch (e) {
    return json({ error: `Error interno: ${e}` }, 500);
  }
});
