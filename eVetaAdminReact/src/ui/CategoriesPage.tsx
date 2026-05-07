import React, { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Switch,
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

function slugify(v: string): string {
  return v
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function CategoriesPage() {
  const [rows, setRows] = useState<Category[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [parentId, setParentId] = useState<string>('');
  const [colorHex, setColorHex] = useState<string>('');
  const [logoUrl, setLogoUrl] = useState<string>('');
  const [bannerUrl, setBannerUrl] = useState<string>('');
  const [specEnabled, setSpecEnabled] = useState(false);
  const [specGroupTitle, setSpecGroupTitle] = useState('');
  const [specFieldLabels, setSpecFieldLabels] = useState('');

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

    const cleanName = name.trim();
    if (!cleanName) {
      setError('Nombre inválido.');
      return;
    }

    const labels = specFieldLabels
      .split('\n')
      .map((x) => x.trim())
      .filter(Boolean);

    const body = {
      name: cleanName,
      slug: slugify(cleanName),
      parent_id: parentId ? parentId : null,
      color_hex: colorHex.trim() || null,
      icon: logoUrl.trim() || null,
      image_url: bannerUrl.trim() || null,
      spec_template_enabled: parentId ? specEnabled && labels.length > 0 : false,
      spec_group_title:
        parentId && specEnabled && labels.length > 0 && specGroupTitle.trim()
          ? specGroupTitle.trim()
          : null,
      spec_field_labels: parentId && specEnabled ? labels : [],
    };

    const res = await coreClient.functions.invoke('admin-upsert-category', {
      body,
      headers: { Authorization: `Bearer ${jwt}`, 'x-admin-access-token': jwt },
    });

    if (res.error) return setError(res.error.message);
    if ((res.data as any)?.error) return setError(String((res.data as any).error));

    setOpen(false);
    setName('');
    setParentId('');
    setColorHex('');
    setLogoUrl('');
    setBannerUrl('');
    setSpecEnabled(false);
    setSpecGroupTitle('');
    setSpecFieldLabels('');
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
          <FormControl fullWidth sx={{ mt: 2 }}>
            <InputLabel>Dentro de</InputLabel>
            <Select
              label="Dentro de"
              value={parentId}
              onChange={(e) => {
                const v = String(e.target.value);
                setParentId(v);
                if (!v) setSpecEnabled(false);
              }}
            >
              <MenuItem value="">Ninguna (categoría principal)</MenuItem>
              {rows
                .filter((r) => r.parent_id == null)
                .map((r) => (
                  <MenuItem key={r.id} value={r.id}>
                    {r.name}
                  </MenuItem>
                ))}
            </Select>
          </FormControl>
          <TextField
            fullWidth
            label="Color borde (#RRGGBB)"
            value={colorHex}
            onChange={(e) => setColorHex(e.target.value)}
            sx={{ mt: 2 }}
          />
          <TextField
            fullWidth
            label="Logo URL"
            value={logoUrl}
            onChange={(e) => setLogoUrl(e.target.value)}
            sx={{ mt: 2 }}
          />
          <TextField
            fullWidth
            label="Banner URL"
            value={bannerUrl}
            onChange={(e) => setBannerUrl(e.target.value)}
            sx={{ mt: 2 }}
          />
          <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mt: 2 }}>
            <Typography sx={{ opacity: parentId ? 1 : 0.5 }}>
              Campos extra en productos (solo subcategorías)
            </Typography>
            <Switch
              disabled={!parentId}
              checked={specEnabled}
              onChange={(e) => setSpecEnabled(e.target.checked)}
            />
          </Stack>
          {parentId && specEnabled && (
            <>
              <TextField
                fullWidth
                label="Nombre del bloque (ej. Especificaciones)"
                value={specGroupTitle}
                onChange={(e) => setSpecGroupTitle(e.target.value)}
                sx={{ mt: 2 }}
              />
              <TextField
                fullWidth
                multiline
                minRows={4}
                label="Apartados (uno por línea)"
                value={specFieldLabels}
                onChange={(e) => setSpecFieldLabels(e.target.value)}
                sx={{ mt: 2 }}
              />
            </>
          )}
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

