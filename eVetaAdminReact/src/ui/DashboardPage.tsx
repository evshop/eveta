import React, { useEffect, useState } from 'react';
import { Card, CardContent, Grid, Typography } from '@mui/material';
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
      <Grid container spacing={2}>
        {metrics.map((m) => (
          <Grid key={m.table} item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Typography sx={{ opacity: 0.75, mb: 0.5 }}>{m.label}</Typography>
                <Typography variant="h4" sx={{ fontWeight: 800 }}>
                  {m.value}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </>
  );
}

