import React, { useEffect, useState } from 'react';
import { Box, Card, CardContent, Typography } from '@mui/material';
import { coreClient } from '../supabase';

type Metric = { label: string; value: number; table: string };

export function DashboardPage() {
  const [metrics, setMetrics] = useState<Metric[]>([
    { label: 'Productos', value: 0, table: 'products' },
    { label: 'Categorías', value: 0, table: 'categories' },
    { label: 'Pedidos', value: 0, table: 'orders' },
    { label: 'Tiendas', value: 0, table: 'profiles_portal' },
  ]);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const next = [...metrics];
      for (let i = 0; i < next.length; i++) {
        const t = next[i].table;
        const { count } = await coreClient.from(t).select('*', { count: 'exact', head: true });
        next[i] = { ...next[i], value: count ?? 0 };
      }
      if (!cancelled) setMetrics(next);
    }
    void load();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      <Typography variant="h5" sx={{ mb: 2, fontWeight: 800 }}>
        Dashboard
      </Typography>
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr', md: 'repeat(4, 1fr)' },
          gap: 2,
        }}
      >
        {metrics.map((m) => (
          <Box key={m.table}>
            <Card>
              <CardContent>
                <Typography sx={{ opacity: 0.75, mb: 0.5 }}>{m.label}</Typography>
                <Typography variant="h4" sx={{ fontWeight: 800 }}>
                  {m.value}
                </Typography>
              </CardContent>
            </Card>
          </Box>
        ))}
      </Box>
    </>
  );
}

