import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from './env';

export const coreClient = createClient(env.coreUrl, env.coreAnon);

// Separate auth project. Persist in a distinct key to avoid collisions.
export const portalAuthClient: SupabaseClient = createClient(env.portalAuthUrl, env.portalAuthAnon, {
  auth: {
    storageKey: 'eveta_admin_portal_auth',
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
});

