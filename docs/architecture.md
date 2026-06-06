# Arquitectura del Proyecto

## Stack tecnológico

| Capa | Tecnología | Versión |
|---|---|---|
| Framework | Flutter (web/PWA) | 3.44+ |
| Estado | Riverpod | 2.6+ |
| Navegación | go_router | 15+ |
| Backend | Firebase (Auth + Firestore + Hosting) | — |
| Escáner | Quagga2 (JS, bundleado local) | — |
| Gráficos | fl_chart | 0.71+ |
| Excel | excel (dart) | — |
| Fuentes | Google Fonts (Inter) | — |

> La app corre como PWA web. El escáner usa Quagga2 vía bridge JS↔Dart porque
> mobile_scanner no funciona en web/Safari iOS.

## Estructura de carpetas

```
lib/
├── main.dart
├── app.dart                          # Router + ShellRoute + MaterialApp
├── firebase_options.dart             # Generado por flutterfire configure
│
├── core/
│   ├── constants/app_constants.dart  # Nombres de colecciones, ceoEmail, etc.
│   ├── scanner/
│   │   └── web_scanner_bridge.dart  # Bindings dart:js_interop → scanner_bridge.js
│   ├── theme/app_theme.dart
│   └── utils/formatters.dart
│
└── features/
    ├── auth/
    │   ├── models/
    │   │   ├── business_model.dart
    │   │   ├── membership_model.dart   # Persona ↔ negocio ↔ rol
    │   │   └── user_model.dart
    │   ├── providers/auth_provider.dart
    │   └── screens/
    │       ├── login_screen.dart
    │       ├── business_select_screen.dart
    │       ├── auth_action_screen.dart  # /recuperar — reset/invitación branded
    │       └── widgets/change_password_dialog.dart
    │
    ├── ceo/
    │   └── screens/ceo_screen.dart     # Crear negocios, preview modo lectura
    │
    ├── admin/
    │   └── screens/admin_panel_screen.dart  # Gestión de trabajadores
    │
    ├── dashboard/
    │   ├── providers/dashboard_provider.dart
    │   └── screens/dashboard_screen.dart
    │
    ├── inventory/
    │   ├── models/product_model.dart
    │   ├── providers/inventory_provider.dart
    │   └── screens/
    │       ├── inventory_screen.dart
    │       └── product_form_screen.dart     # Agregar/editar + escaneo
    │
    ├── pos/
    │   ├── models/
    │   │   ├── sale_model.dart
    │   │   └── cart_item.dart
    │   ├── providers/pos_provider.dart
    │   └── screens/
    │       ├── pos_screen.dart              # Escaneo + búsqueda manual
    │       └── checkout_screen.dart
    │
    ├── fiados/
    │   ├── models/client_model.dart
    │   ├── providers/fiados_provider.dart
    │   └── screens/
    │       ├── fiados_screen.dart
    │       └── client_detail_screen.dart
    │
    └── reports/
        ├── providers/reports_provider.dart
        ├── utils/excel_export.dart
        └── screens/
            ├── reports_screen.dart
            └── daily_reports_screen.dart

web/
├── index.html           # Loader PWA con auto-update y cache-busting
├── quagga.min.js        # Motor Quagga2 (1D: EAN/UPC/Code128/39), bundleado local
└── scanner_bridge.js    # Overlay full-screen, botón HTML para iOS, beep + vibración
```

## Flujo de navegación

```
/login
  └── (autenticado)
        ├── CEO → /ceo
        │     └── (toca negocio) → /dashboard [preview solo lectura]
        ├── 1 membresía → /dashboard [Shell]
        └── 2+ membresías → /select-business → /dashboard [Shell]

/dashboard [ShellRoute]
  ├── /dashboard
  ├── /pos
  │     └── /pos/checkout
  ├── /inventory
  │     ├── /inventory/add
  │     └── /inventory/edit/:id
  ├── /fiados
  │     └── /fiados/:clientId
  ├── /reports
  │     └── /reports/daily/:date
  └── /admin-panel

/recuperar   # Ruta pública — reset password + invitaciones (sin sesión)
```

## Sistema de roles y membresías

- **CEO:** detectado por `AppConstants.ceoEmail`. No usa membresías. Accede a todos los negocios en preview (solo lectura).
- **Admin / Trabajador:** la colección `memberships` vincula `{ email, businessId, role, isActive }`. Al login, si hay 2+ membresías activas se muestra el selector; si hay una sola se entra directo.
- **Invitar:** se crea la membresía; si el correo no tiene cuenta Firebase, se crea con clave aleatoria y se envía link de recuperación para que el usuario ponga la suya.
- **Migración legacy:** `_migrateLegacyMembership` convierte `users/{uid}.businessId+role` al modelo de membresías una sola vez al login.

## Patrón de estado (Riverpod)

- **StreamProvider** → datos en tiempo real de Firestore (productos, clientes, ventas del día, trabajadores)
- **FutureProvider** → consultas puntuales (reportes por periodo, negocios del CEO)
- **StateProvider** → estado de UI y negocio activo (`selectedBusinessProvider`, `selectedMembershipProvider`, periodo de reporte, búsqueda)
- **AsyncNotifier** → operaciones con estado de carga (login, crear producto, checkout)
- **NotifierProvider** → estado del carrito de compras

## Rendimiento — filtros server-side

Las ventas y pagos se filtran por fecha en el servidor, no en el cliente:

```
where(businessId).where(createdAt >= inicio).where(createdAt <= fin).orderBy(createdAt desc)
```

Requiere índices compuestos en Firestore (`firestore.indexes.json`):
- `sales`: `businessId ASC + createdAt DESC`
- `fiado_payments`: `businessId ASC + createdAt DESC`

Si se añade un `where(igualdad) + orderBy(otro campo)`, hay que agregar el índice y hacer `firebase deploy --only firestore:indexes`.

## Escáner de código de barras (PWA/Safari iOS)

Motor Quagga2 vía bridge JS↔Dart:

1. `web/quagga.min.js` — librería Quagga2 bundleada local (no CDN)
2. `web/scanner_bridge.js` — overlay full-screen, init Quagga, beep, línea de mira
3. `lib/core/scanner/web_scanner_bridge.dart` — `dart:js_interop` bindings

Truco para Safari iOS (getUserMedia exige gesto DOM real): `showScanTrigger` coloca un `<button>` HTML transparente encima del botón Flutter antes del primer toque. Así el primer tap va directo al elemento HTML y Safari habilita la cámara.

Config clave: `numOfWorkers: 0` (evita worker-blobs que rompen en Safari), rechazo de lecturas con `avgError > 0.20`.

## Integridad de datos

- **Código de barras único:** `product_form` valida antes de guardar que ningún otro producto use el mismo código.
- **Stock sin sobreventa:** `POSNotifier.checkout` usa una transacción Firestore que re-lee el stock real y aborta si el carrito lo supera.
- **Sin doble-submit:** checkout y registro de pago usan un flag síncrono (`_submitting`) seteado antes del primer `await`.

## Firestore — colecciones

```
users/{uid}           → role, businessId (legacy), isActive
businesses/{id}       → name, ownerId, createdAt
memberships/{id}      → email, name, businessId, role, isActive, createdAt
products/{id}         → businessId, name, barcode?, price, cost?, stock, minStock, hasBarcode
sales/{id}            → businessId, userId, userName, items[], total, paymentType, clientId?, createdAt
clients/{id}          → businessId, name, phone?, totalDebt
fiado_payments/{id}   → clientId, clientName, businessId, amount, note?, createdAt
```

## Auto-update PWA

`web/index.html` implementa un loader que actualiza la app automáticamente:
1. Baja `flutter_bootstrap.js` con `?_=timestamp` (nunca cacheado)
2. Si `serviceWorkerVersion` cambió: borra todos los caches, desregistra el Service Worker, recarga una vez
3. Todos los scripts fijos (quagga, scanner_bridge) se cargan con `?v=<version>` para bustar el caché HTTP de disco

## Reglas de Firestore (estado actual)

- Requieren usuario autenticado para todo acceso
- Negocios: solo el CEO puede crear/editar/borrar
- Paths no mapeados: deniegan por defecto
- Pendiente: aislamiento por negocio (worker de A no puede leer datos de B vía API directa)
