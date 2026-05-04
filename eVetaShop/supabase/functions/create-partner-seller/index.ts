import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-access-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

type Body = {
  email?: string;
  password?: string;
  full_name?: string;
  shop_name?: string;
  shop_description?: string;
  access_token?: string;
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const looksLikeJwt = (t: string): boolean => !!t && t.split(".").length === 3;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({ error: "server_misconfigured_missing_env" }, 500);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  try {
    const rawJson = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const body = (rawJson["body"] && typeof rawJson["body"] === "object")
      ? (rawJson["body"] as Record<string, unknown>)
      : rawJson;

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwtFromHeader = authHeader.replace(/^Bearer\s+/i, "").trim();
    const jwtFromCustomHeader = req.headers.get("x-admin-access-token")?.trim() ?? "";
    const jwtFromBody = typeof body["access_token"] === "string" ? body["access_token"].trim() : "";
    const jwtFromBodyAlt = typeof body["accessToken"] === "string" ? body["accessToken"].trim() : "";

    const jwt = [jwtFromBodyAlt, jwtFromBody, jwtFromCustomHeader, jwtFromHeader]
      .find((t) => looksLikeJwt(t)) ?? "";

    if (!jwt) return json({ error: "invalid_jwt_format" }, 401);

    // Validar admin con JWT del usuario (no usar profiles.is_admin).
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const { data: isAdmin, error: adminErr } = await supabaseUser.rpc("profile_is_admin");
    if (adminErr) return json({ error: `admin_check_failed: ${adminErr.message}` }, 403);
    if (isAdmin !== true) return json({ error: "forbidden" }, 403);

    const email = typeof body["email"] === "string" ? body["email"].trim().toLowerCase() : "";
    const password = typeof body["password"] === "string" ? body["password"] : "";
    const fullName = typeof body["full_name"] === "string" ? body["full_name"].trim() : "";
    const shopName = typeof body["shop_name"] === "string" ? body["shop_name"].trim() : "";
    const shopDescription = typeof body["shop_description"] === "string" ? body["shop_description"].trim() : "";

    if (!email || !email.includes("@") || !password || password.length < 6) {
      return json({ error: "email_y_contraseña_válidos_requeridos_mín_6_caracteres" }, 400);
    }
    if (!fullName || !shopName) {
      return json({ error: "nombre_y_tienda_requeridos" }, 400);
    }

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, app: "portal_seller" },
    });

    if (createErr || !created?.user) {
      return json({ error: createErr?.message ?? "create_user_failed" }, 400);
    }

    const userId = created.user.id;

    // Limpia fila auto-creada en profiles si algún trigger la insertó.
    // Estricto: tiendas no viven en profiles.
    await supabaseAdmin.from("profiles").delete().eq("id", userId).catch(() => {});

    const { data: portalRow, error: portalErr } = await supabaseAdmin
      .from("profiles_portal")
      .insert({
        auth_user_id: userId,
        email,
        full_name: fullName,
        shop_name: shopName,
        shop_description: shopDescription,
        is_admin: false,
        is_seller: true,
        is_partner_verified: true,
        partner_display_order: 0,
        is_active: true,
      })
      .select("id")
      .single();

    if (portalErr || !portalRow?.id) {
      await supabaseAdmin.auth.admin.deleteUser(userId).catch(() => {});
      return json(
        { error: `profiles_portal_insert_failed: ${portalErr?.message ?? "unknown"}` },
        400,
      );
    }

    return json({
      ok: true,
      user_id: userId,
      portal_profile_id: portalRow.id,
      email,
    });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "unexpected_error" }, 500);
  }
});