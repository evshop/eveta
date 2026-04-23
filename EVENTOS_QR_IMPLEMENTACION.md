# Implementacion del modulo de Eventos con entradas digitales (QR)

Este documento resume todos los cambios realizados para extender el sistema eVeta con un modulo de eventos y tickets QR, reutilizando la infraestructura existente (usuarios, autenticacion, Supabase, panel admin y apps Flutter).

## Objetivo implementado

Se incorporo un flujo end-to-end para:

- publicar eventos en la app cliente;
- comprar entradas (modo normal y modo prueba sin pago);
- generar tickets digitales con QR;
- controlar ingresos por cantidad de personas;
- bloquear/desbloquear beneficios segun ingreso completo;
- canjear beneficios desde una app independiente de scanner;
- administrar eventos y visualizar metricas en el panel admin.

## Arquitectura usada

- **Backend y datos**: Supabase (tablas + RLS + funciones SQL/RPC).
- **App cliente**: `eVetaShop` (Flutter).
- **Panel admin**: `eVetaAdminWeb` (Flutter web).
- **App scanner**: `eVetaScanner` (Flutter nuevo proyecto).
- **Auth y perfiles**: reutiliza `auth.users` y `profiles`.

## Scripts SQL creados/actualizados

### 1) Esquema y seguridad

- `eVetaAdminWeb/scripts/020_events_qr_schema_rls.sql`

Incluye:

- tablas:
  - `events`
  - `event_ticket_types`
  - `event_tickets`
  - `ticket_benefits`
  - `ticket_action_logs`
- tipo enum:
  - `ticket_benefit_state` (`blocked`, `active`, `complete`)
- indices, constraints y triggers `updated_at`
- funciones auxiliares de permisos:
  - `profile_is_staff()`
- politicas RLS para cliente/admin/staff scanner

### 2) Funciones de negocio transaccionales

- `eVetaAdminWeb/scripts/021_events_qr_business_functions.sql`

Funciones implementadas:

- `event_set_benefits_state(p_ticket_id)`
- `issue_tickets_on_order_paid(p_order_id)`
- `consume_ticket_entry(p_qr_token, p_quantity)`
- `consume_ticket_benefit(p_qr_token, p_benefit_type, p_quantity)`
- `get_ticket_scan_state(p_qr_token)`

Reglas implementadas:

- no exceder `people_count`;
- beneficios bloqueados hasta completar ingreso;
- canje solo en estado permitido;
- logs de entrada/canje en `ticket_action_logs`.

### 3) Vinculo de entradas con checkout actual

- `eVetaAdminWeb/scripts/022_products_event_ticket_type_link.sql`

Incluye:

- columna `products.event_ticket_type_id` (FK a `event_ticket_types`);
- indice parcial para lookup.

### 4) Compra de prueba sin pago

- `eVetaAdminWeb/scripts/023_test_purchase_event_ticket.sql`

Incluye:

- funcion `test_purchase_event_ticket(p_ticket_type_id, p_quantity)`:
  - crea tickets directos para el usuario autenticado;
  - crea beneficios asociados;
  - actualiza `sold_count`.

## Cambios en eVetaShop (app cliente)

### Archivos nuevos

- `eVetaShop/lib/utils/events_service.dart`
- `eVetaShop/lib/utils/tickets_service.dart`
- `eVetaShop/lib/utils/feature_flags.dart`
- `eVetaShop/lib/screens/events_screen.dart`
- `eVetaShop/lib/screens/event_detail_screen.dart`
- `eVetaShop/lib/screens/my_tickets_screen.dart`

### Archivos modificados

- `eVetaShop/lib/screens/home_screen.dart`
  - seccion visual para ingresar a **Eventos** (controlada por feature flag).
- `eVetaShop/lib/screens/menu_screen.dart`
  - acceso a **Mis entradas**.
- `eVetaShop/lib/screens/checkout_payment_screen.dart`
  - emision de tickets post-confirmacion de pago (flujo normal).
- `eVetaShop/lib/utils/order_service.dart`
  - llamada a `issue_tickets_on_order_paid`.
- `eVetaShop/pubspec.yaml`
  - soporte para descarga/compartir QR.

### Flujo implementado en cliente

1. Usuario entra a `Eventos`.
2. Ve lista y detalle de evento con tipos de entrada.
3. Al tocar entrada:
   - opcion A: enviar al carrito normal;
   - opcion B: compra de prueba inmediata (sin pago).
4. Luego puede ver tickets en `Mis entradas`.
5. En cada ticket:
   - QR unico;
   - estado de personas usadas;
   - estado de beneficios;
   - opcion de descargar/compartir QR.

## Cambios en eVetaAdminWeb (panel admin)

### Archivos nuevos

- `eVetaAdminWeb/lib/services/events_service.dart`
- `eVetaAdminWeb/lib/screens/events_screen.dart`
- `eVetaAdminWeb/lib/screens/event_dashboard_screen.dart`

### Archivos modificados

- `eVetaAdminWeb/lib/screens/admin_shell_screen.dart`
  - nuevas secciones:
    - Gestion de Eventos
    - Dashboard Evento

### Funcionalidad implementada

- CRUD de eventos;
- CRUD de tipos de entrada por evento;
- configuracion basica de beneficios por tipo;
- dashboard de metricas:
  - tickets vendidos;
  - personas ingresadas;
  - beneficios canjeados;
  - volumen de logs.

### Sincronizacion ticket type -> producto

Se implemento sincronizacion automatica para que cada `event_ticket_type` tenga su `product` espejo:

- al crear/editar tipo de entrada: crea/actualiza producto asociado;
- al eliminar tipo de entrada: elimina producto asociado.

Esto resuelve el error:

- "entrada no disponible para comprar aun".

## Nueva app eVetaScanner (independiente)

### Proyecto creado

- `eVetaScanner/`

### Configuracion

- dependencias:
  - `supabase_flutter`
  - `flutter_dotenv`
  - `mobile_scanner`
- `.env` con credenciales Supabase
- app conectada a RPC de scanner

### Flujo implementado

- escaneo de QR;
- consulta de estado del ticket (`get_ticket_scan_state`);
- accion de registrar entrada (`consume_ticket_entry`);
- accion de canjear beneficio (`consume_ticket_benefit`);
- UI operativa para staff.

## Ajustes y correcciones durante implementacion

- correccion de `setState` asincrono que causaba excepciones en app cliente/admin:
  - error: `setState() callback argument returned a Future`.
- correccion de `pubspec.yaml` en `eVetaShop`:
  - dependencia duplicada `path_provider`.
- compatibilidad SQL:
  - reemplazo de `gen_random_bytes(...)` por token basado en `md5(...)` donde aplicaba, para evitar error por funcion no disponible.

## Checklist de despliegue/ejecucion

Ejecutar en Supabase SQL Editor, en orden:

1. `020_events_qr_schema_rls.sql`
2. `021_events_qr_business_functions.sql`
3. `022_products_event_ticket_type_link.sql`
4. `023_test_purchase_event_ticket.sql`

Luego:

- correr `flutter pub get` en `eVetaShop` y `eVetaScanner`;
- levantar `eVetaAdminWeb`, `eVetaShop` y `eVetaScanner`.

## Estado actual

Implementacion funcional del modulo de eventos QR completada con:

- backend de tickets y beneficios;
- app cliente con eventos/mis entradas/compra de prueba;
- panel admin con gestion y dashboard;
- app scanner independiente para staff.

## Recomendaciones siguientes

- agregar tests automatizados para RPC criticas (`consume_ticket_entry`, `consume_ticket_benefit`);
- endurecer idempotencia en escaneo concurrente;
- agregar exportacion de reportes por evento;
- revisar estrategia final de token QR (si se requiere criptografia adicional o expiracion).
