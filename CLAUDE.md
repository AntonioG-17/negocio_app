# NegocioApp — Contexto del proyecto

App de inventario y dashboard para negocio físico, desplegada como **PWA web** en Firebase Hosting.

**URL live:** https://proyecto-app-negocio.web.app  
**GitHub:** https://github.com/AntonioG-17/negocio_app  
**Carpeta local:** `/Users/antonioquilodrangeldes/Desktop/Carpeta Idea Proyectos/negocio_app/`

## Stack

Flutter 3.44 + Firebase (Firestore + Auth) + Riverpod + go_router + mobile_scanner v7

## Despliegue

La app corre como PWA web (instalada en iPhone desde Safari → "Agregar a pantalla de inicio").

```bash
flutter build web --release && firebase deploy --only hosting
```

Firebase project: `proyecto-app-negocio`

## Sistema de roles

| Rol | Acceso | Creado por |
|-----|--------|------------|
| **CEO** | Panel CEO: crear negocios + admins | Auto-detectado por email |
| **Admin** | Todo: dashboard (todas ventas), inventario, fiados, reportes, panel equipo | CEO |
| **Trabajador** | Dashboard (solo sus ventas) + POS | Admin |

- CEO se detecta por email = `AppConstants.ceoEmail` (antonio.geldes1701@gmail.com)
- En el primer login del CEO, se crea el perfil automáticamente en `users/{uid}`
- Admin/Worker: al login, su negocio se auto-carga desde `users/{uid}.businessId`
- No hay registro público. Solo login.

## Firestore collections

- `users/{uid}` — perfil con role + businessId
- `businesses/{id}` — negocios
- `products/{id}` — inventario (por businessId)
- `sales/{id}` — ventas (por businessId + userId)
- `clients/{id}` — fiados
- `fiado_payments/{id}` — pagos de fiados

## Cuenta CEO

- **Email:** antonio.geldes1701@gmail.com (ya existe en Firebase Auth)
- **UID:** hvWgAvCj53YoFsQn4Yl31UhKrG73
- El perfil CEO se crea automáticamente en el primer login (no había perfil antes)
- Base de datos limpiada (slate limpio, sin datos demo)

## Scanner POS (web/PWA)

Fix en `lib/features/pos/screens/pos_screen.dart`:
- `autoStart: false`, `CameraFacing.back`, formatos explícitos (EAN-13, EAN-8, Code128, UPC-A, UPC-E, QR)
- `WidgetsBindingObserver` para ciclo de vida
- Start/stop manual + popups en vez de SnackBars para producto no encontrado

## Módulos implementados

- Auth: solo login (sin registro público)
- Dashboard: ventas del día filtradas por rol
- Inventario: CRUD productos + escaneo
- POS: escaneo + búsqueda + carrito + checkout
- Fiados: clientes + historial + pagos
- Reportes: gráficos semana/mes/año + exportar Excel
- CEO Panel: crear negocios + admins
- Admin Panel: crear/remover trabajadores

## Permisos por rol — Inventario

| Acción | CEO | Admin | Trabajador |
|--------|-----|-------|------------|
| Ver inventario | - | ✓ | ✓ (solo lectura) |
| Agregar producto | - | ✓ | ✗ |
| Editar/eliminar producto | - | ✓ | ✗ |

- Trabajadores ven el tab Inventario pero no tienen FAB ni pueden tocar los tiles para editar
- Router bloquea `/inventory/add` y `/inventory/edit/*` para workers → redirige a `/inventory`

## Historial de ventas — campo userName

- `Sale` tiene campo `userName?: String` guardado en Firestore al crear cada venta
- `POSNotifier._userName` lee `userProfileProvider.valueOrNull?.name` al hacer checkout
- El Excel de reportes incluye columna **Trabajador** en la hoja "Ventas"
- Ventas antiguas (anteriores a este cambio) mostrarán '-' en esa columna

## Excel — estructura actual

**Hoja "Resumen":** Periodo, Exportado, Ingresos totales, Total ventas, Cobrado, Fiados  
**Hoja "Ventas":** Fecha, Hora, Trabajador, Productos, Total, Tipo de pago, Cliente

## Por implementar

- CEO preview mode: navegar cualquier negocio en modo lectura (ver ventas + inventario, descargar Excel)
