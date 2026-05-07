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

type Category = {
  id: string;
  name: string;
  slug: string;
  parent_id: string | null;
};

export function CategoriesPage() {
  const [rows, setRows] = useState<Category[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');

  async function refresh() {
    const { data, error } = await coreClient
      .from('categories')
      .select('id,name,slug,parent_id')
      .order('name');
    if (error) {
      setError(error.message);
      return;
    }
    setRows((data ?? []) as any);
  }

  useEffect(() => {
    void refresh();
  }, []);

  async function save() {
    setError(null);
    const session = (await portalAuthClient.auth.getSession()).data.session;
    const jwt = session?.access_token;
    if (!jwt) {
      setError('Sesión expirada. Vuelve a iniciar sesión.');
      return;
    }

    // Use Core Edge Function admin-upsert-category (already deployed).
    const res = await coreClient.functions.invoke('admin-upsert-category', {
      body: {
        name: name.trim(),
        slug: name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, ''),
      },
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

    setOpen(false);
    setName('');
    await refresh();
  }

  return (
    <>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h5" sx={{ fontWeight: 800 }}>
          Categorías
        </Typography>
        <Button variant="contained" onClick={() => setOpen(true)}>
          Nueva categoría
        </Button>
      </Stack>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      <Box sx={{ opacity: 0.8 }}>
        {rows.map((c) => (
          <div key={c.id}>
            {c.name} <span style={{ opacity: 0.6 }}>({c.slug})</span>
          </div>
        ))}
      </Box>

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>Nueva categoría</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            fullWidth
            label="Nombre"
            value={name}
            onChange={(e) => setName(e.target.value)}
            sx={{ mt: 1 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancelar</Button>
          <Button variant="contained" disabled={!name.trim()} onClick={save}>
            Guardar
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}

