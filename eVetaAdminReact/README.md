## eVetaAdminReact

Admin web en React (Vite + TS) para eVeta, usando:

- **Portal Auth** (login/sesión): `VITE_PORTAL_AUTH_*`
- **Core** (datos + Edge Functions admin): `VITE_CORE_*`

### Requisitos

- Node.js 18+

### Local

```bash
cd eVetaAdminReact
npm install
cp .env.example .env
npm run dev
```

### Vercel

- Configura Environment Variables:
  - `VITE_CORE_SUPABASE_URL`
  - `VITE_CORE_SUPABASE_ANON_KEY`
  - `VITE_PORTAL_AUTH_SUPABASE_URL`
  - `VITE_PORTAL_AUTH_SUPABASE_ANON_KEY`
- Build command: `npm run build`
- Output dir: `dist`

