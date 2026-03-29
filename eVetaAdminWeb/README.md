# eVeta Admin Web

Panel administrativo web (Flutter Web) para operación interna de eVeta.

## Módulos iniciales

- Login solo para cuentas con `profiles.is_admin = true`
- Dashboard con métricas básicas
- CRUD de productos de la cuenta admin actual
- Secciones base para tiendas y pedidos (siguiente fase)

## Configuración

1. Editar `.env`:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
2. Ejecutar:
   - `flutter pub get`
   - `flutter run -d chrome`
