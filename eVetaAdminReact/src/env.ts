function required(name: string): string {
  const v = (import.meta.env[name] ?? '').toString().trim();
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

export const env = {
  coreUrl: required('VITE_CORE_SUPABASE_URL'),
  coreAnon: required('VITE_CORE_SUPABASE_ANON_KEY'),
  portalAuthUrl: required('VITE_PORTAL_AUTH_SUPABASE_URL'),
  portalAuthAnon: required('VITE_PORTAL_AUTH_SUPABASE_ANON_KEY'),
};

