import React, { useEffect, useMemo, useState } from 'react';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import {
  AppBar,
  Box,
  Button,
  Container,
  Drawer,
  List,
  ListItemButton,
  ListItemText,
  Toolbar,
  Typography,
} from '@mui/material';
import { portalAuthClient } from '../supabase';
import { useAdminGate } from './useAdminGate';

const navItems = [
  { path: '/', label: 'Dashboard' },
  { path: '/categories', label: 'Categorías' },
  { path: '/stores', label: 'Tiendas' },
];

export function AppShell() {
  const nav = useNavigate();
  const loc = useLocation();
  const { status, error } = useAdminGate();
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    const s = portalAuthClient.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
    });
    void s;
    const { data: sub } = portalAuthClient.auth.onAuthStateChange((_evt, session) => {
      setEmail(session?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (status === 'signed_out') nav('/login', { replace: true });
  }, [status, nav]);

  const title = useMemo(() => {
    const x = navItems.find((n) => n.path === loc.pathname);
    return x?.label ?? 'eVeta Admin';
  }, [loc.pathname]);

  if (status === 'checking') {
    return (
      <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <Typography>Cargando…</Typography>
      </Box>
    );
  }

  if (status === 'forbidden') {
    return (
      <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center', px: 2 }}>
        <Box>
          <Typography variant="h5" sx={{ mb: 1 }}>
            Sin permisos de administrador
          </Typography>
          <Typography sx={{ opacity: 0.8, mb: 2 }}>{error ?? 'Tu cuenta no es admin.'}</Typography>
          <Button
            variant="contained"
            onClick={async () => {
              await portalAuthClient.auth.signOut();
              nav('/login', { replace: true });
            }}
          >
            Cerrar sesión
          </Button>
        </Box>
      </Box>
    );
  }

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar position="fixed">
        <Toolbar>
          <Typography variant="h6" sx={{ flex: 1 }}>
            {title}
          </Typography>
          <Typography sx={{ opacity: 0.8, mr: 2, fontSize: 13 }}>{email ?? ''}</Typography>
          <Button
            color="inherit"
            onClick={async () => {
              await portalAuthClient.auth.signOut();
              nav('/login', { replace: true });
            }}
          >
            Salir
          </Button>
        </Toolbar>
      </AppBar>
      <Drawer variant="permanent" sx={{ width: 240, [`& .MuiDrawer-paper`]: { width: 240 } }}>
        <Toolbar />
        <List>
          {navItems.map((n) => (
            <ListItemButton
              key={n.path}
              selected={loc.pathname === n.path}
              onClick={() => nav(n.path)}
            >
              <ListItemText primary={n.label} />
            </ListItemButton>
          ))}
        </List>
      </Drawer>
      <Box component="main" sx={{ flex: 1 }}>
        <Toolbar />
        <Container sx={{ py: 3 }}>
          <Outlet />
        </Container>
      </Box>
    </Box>
  );
}

