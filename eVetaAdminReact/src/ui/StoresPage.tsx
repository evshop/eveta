import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, Stack, Typography } from '@mui/material';
import { coreClient, portalAuthClient } from '../supabase';

type StoreRow = {
  id: string;
  email: string;
  shop_name: string | null;
  is_seller: boolean;
  is_active: boolean;
};

export function StoresPage() {
  const [rows, setRows] = useState<StoreRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    const { data, error } = await coreClient
      .from('profiles_portal')
      .select('id,email,shop_name,is_seller,is_active')
      .order('created_at', { ascending: false });
    if (error) {
      setError(error.message);
      return;
    }
    setRows((data ?? []) as any);
  }

  useEffect(() => {
    void refresh();
  }, []);

  async function deleteStore(profileId: string) {
    setError(null);
    const session = (await portalAuthClient.auth.getSession()).data.session;
    const jwt = session?.access_token;
    if (!jwt) {
      setError('Sesión expirada. Vuelve a iniciar sesión.');
      return;
    }
    const res = await coreClient.functions.invoke('admin-delete-store', {
      body: { profile_id: profileId },
      headers: { Authorization: `Bearer ${jwt}`, 'x-admin-access-token': jwt },
    });
    if (res.error) {
      setError(res.error.message);
      return;
    }
    if (res.data?.error) {
      setError(String(res.data.error));
      return;
    }
    await refresh();
  }

  return (
    <>
      <Typography variant="h5" sx={{ fontWeight: 800, mb: 2 }}>
        Tiendas
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      <Box sx={{ display: 'grid', gap: 1 }}>
        {rows.map((r) => (
          <Stack
            key={r.id}
            direction="row"
            justifyContent="space-between"
            alignItems="center"
            sx={{
              p: 1.25,
              border: '1px solid rgba(255,255,255,0.12)',
              borderRadius: 1.5,
            }}
          >
            <Box>
              <Typography sx={{ fontWeight: 700 }}>{r.shop_name ?? '(sin nombre)'}</Typography>
              <Typography sx={{ opacity: 0.7, fontSize: 13 }}>{r.email}</Typography>
            </Box>
            <Button color="error" variant="outlined" onClick={() => void deleteStore(r.id)}>
              Borrar
            </Button>
          </Stack>
        ))}
      </Box>
    </>
  );
}

