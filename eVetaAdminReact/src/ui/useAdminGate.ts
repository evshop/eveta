import { useEffect, useState } from 'react';
import { coreClient, portalAuthClient } from '../supabase';

type GateStatus = 'checking' | 'signed_out' | 'forbidden' | 'ok';

export function useAdminGate(): { status: GateStatus; error?: string } {
  const [status, setStatus] = useState<GateStatus>('checking');
  const [error, setError] = useState<string | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      const { data } = await portalAuthClient.auth.getSession();
      const session = data.session;
      if (!session?.user?.email) {
        if (!cancelled) setStatus('signed_out');
        return;
      }

      const email = session.user.email.trim().toLowerCase();
      const { data: row, error: e } = await coreClient
        .from('profiles_portal')
        .select('is_admin, is_active')
        .ilike('email', email)
        .maybeSingle();

      if (e) {
        if (!cancelled) {
          setStatus('forbidden');
          setError(e.message);
        }
        return;
      }

      const ok = row?.is_admin === true && row?.is_active === true;
      if (!cancelled) setStatus(ok ? 'ok' : 'forbidden');
    }

    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  return { status, error };
}

