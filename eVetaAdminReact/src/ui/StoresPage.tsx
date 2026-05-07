import React, { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
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
  const [confirmId, setConfirmId] = useState<string | null>(null);
  const [confirmText, setConfirmText] = useState('');
  const [deleting, setDeleting] = useState(false);

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
    setDeleting(true);
    try {
      const res = await coreClient.functions.invoke('admin-delete-store', {
        body: { profile_id: profileId },
        headers: { Authorization: `Bearer ${jwt}`, 'x-admin-access-token': jwt },
      });
      if (res.error) return setError(res.error.message);
      if ((res.data as any)?.error) return setError(String((res.data as any).error));
      await refresh();
    } finally {
      setDeleting(false);
    }
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
            <Button
              color="error"
              variant="outlined"
              disabled={deleting}
              onClick={() => {
                setConfirmId(r.id);
                setConfirmText('');
              }}
            >
              Borrar
            </Button>
          </Stack>
        ))}
      </Box>

      <Dialog open={!!confirmId} onClose={() => (deleting ? null : setConfirmId(null))} fullWidth maxWidth="xs">
        <DialogTitle>Borrar tienda</DialogTitle>
        <DialogContent>
          <Typography sx={{ opacity: 0.8, mb: 1 }}>
            Escribe <b>BORRAR</b> para confirmar.
          </Typography>
          <TextField
            fullWidth
            value={confirmText}
            onChange={(e) => setConfirmText(e.target.value)}
            placeholder="BORRAR"
          />
        </DialogContent>
        <DialogActions>
          <Button disabled={deleting} onClick={() => setConfirmId(null)}>
            Cancelar
          </Button>
          <Button
            color="error"
            variant="contained"
            disabled={deleting || confirmText.trim().toUpperCase() !== 'BORRAR' || !confirmId}
            onClick={() => confirmId && void deleteStore(confirmId).then(() => setConfirmId(null))}
          >
            {deleting ? 'Borrando…' : 'Borrar'}
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}

