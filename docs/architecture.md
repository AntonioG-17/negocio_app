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

> La app corre como PWA web. El escáner usa Quagga2 vía bridge JS↔Dart porque mobile_scanner no funciona en web/Safari iOS.

## Estructura de carpetas

```
lib/
├── main.dart                          # Firebase init + Firestore offline persistence
├── app.dart                           # Router + ShellRoute + membership stream listener
├── firebase_options.dart              # Generado por flutterfire configure
│
├── core/
│   ├── constants/app_constants.dart   # Colecciones, ceoEmail, versión, defaultMinStock
│   ├── scanner/
│   │   └── web_scanner_bridge.dart   # Bindings dart:js_interop → scanner_bridge.js
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
    │       ├── business_select_screen.dart  # ConsumerStatefulWidget con _selecting guard
    │       ├── auth_action_screen.dart      # /recuperar — reset/invitación branded
    │       └── widgets/change_password_dialog.dart
    │
    ├── ceo/
    │   └── screens/ceo_screen.dart          # Crear negocios, preview modo lectura
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
    │   ├── providers/pos_provider.dart      # Checkout con transacción Firestore
    │   └── screens/
    │       ├── pos_screen.dart              # WidgetsBindingObserver para scanner lifecycle
    │       └── checkout_screen.dart
    │
    ├── fiados/
    │   ├── models/client_model.dart
    │   ├── providers/fiados_provider.dart   # addPayment con transacción anti-deuda-negativa
    │   └── screens/
    │       ├── fiados_screen.dart
    │       └── client_detail_screen.dart    # Pantalla "Cliente eliminado" si doc desaparece
    │
    └── reports/
        ├── providers/reports_provider.dart
        ├── utils/excel_export.dart
        └── screens/
            ├── reports_screen.dart
            └── daily_reports_screen.dart

web/
├── index.html           # Loader PWA: auto-update, timeouts para red lenta, hint de carga lenta
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
  ├── /pos → /pos/checkout
  ├── /inventory → /inventory/add | /inventory/edit/:id
  ├── /fiados → /fiados/:clientId
  ├── /reports → /reports/daily/:date
  └── /admin-panel

/recuperar   # Pública — reset password + invitaciones (sin sesión)
```

## Sistema de roles y membresías

- **CEO:** detectado por `AppConstants.ceoEmail`. No usa membresías. Accede a todos los negocios en preview (solo lectura).
- **Admin / Trabajador:** colección `memberships` vincula `{ email, businessId, role, isActive }`.
- Al login: 0 membresías → "sin negocio"; 1 → entra directo; 2+ → selector de negocio.
- **Expulsión en tiempo real:** `userMembershipsProvider` es `StreamProvider` — si el admin desactiva al worker, el listener en `app.dart` limpia el estado y el router lo expulsa.

## Patrón de estado (Riverpod)

| Tipo | Uso |
|------|-----|
| `StreamProvider` | Datos en tiempo real: productos, clientes, ventas del día, membresías |
| `FutureProvider` | Consultas puntuales: reportes por periodo, negocios del CEO |
| `StateProvider` | UI y selección: negocio activo, membresía, periodo, búsqueda |
| `AsyncNotifier` | Operaciones: login, crear producto, checkout, pagos |
| `NotifierProvider` | Carrito de compras |

## Escáner de código de barras (PWA/Safari iOS)

1. `web/quagga.min.js` — Quagga2 bundleado local (no CDN)
2. `web/scanner_bridge.js` — overlay full-screen, beep, línea de mira, botón HTML para iOS
3. `lib/core/scanner/web_scanner_bridge.dart` — `dart:js_interop` bindings

**Truco iOS:** `showScanTrigger` coloca un `<button>` HTML transparente encima del botón Flutter antes del primer toque — Safari exige gesto DOM real para `getUserMedia`.

**Config clave:** `numOfWorkers: 0` (evita worker-blobs en Safari), rechazo con `avgError > 0.20`.

**Lifecycle:** `POSScreen` implementa `WidgetsBindingObserver` — para la cámara al ir a segundo plano.

## Integridad de datos

| Garantía | Mecanismo |
|----------|-----------|
| Stock sin sobreventa | Transacción Firestore en checkout — re-lee stock real |
| Deuda nunca negativa | Transacción Firestore en `addPayment` — re-lee deuda real |
| Sin doble-submit | Flag síncrono `_submitting` antes del primer `await` |
| Ventas immutables | Firestore rules: `update/delete` solo para CEO |
| Pagos immutables | Firestore rules: `update/delete` solo para CEO |
| Sales.userId correcto | Firestore rules: `userId == request.auth.uid` en create |

## Firestore — esquema completo

```
users/{uid}
  email, name, businessId (legacy), businessIds[] (nuevo), isActive, role, createdAt

businesses/{id}
  name, ownerId, createdAt

memberships/{id}
  email (lowercase), name, businessId, role: admin|worker, isActive, createdAt

products/{id}
  businessId, name, barcode?, price, cost?, stock, minStock, hasBarcode, category?, createdAt, updatedAt

sales/{id}
  businessId, userId, userName, items[{productId,productName,quantity,price}],
  total, paymentType: cash|fiado|card, clientId?, clientName?, createdAt

clients/{id}
  businessId, name, phone?, totalDebt, createdAt, updatedAt

fiado_payments/{id}
  clientId, clientName (denorm.), businessId, amount, note?, createdAt
```

## Rendimiento — filtros server-side

```dart
// Dashboard — ventas de hoy
where(businessId).where(createdAt >= startOfDay).orderBy(createdAt desc)

// Reportes — ventas por periodo
where(businessId).where(createdAt >= start).where(createdAt <= end).orderBy(createdAt desc)
```

Índices compuestos en `firestore.indexes.json`:
- `sales`: `businessId ASC + createdAt DESC`
- `fiado_payments`: `businessId ASC + createdAt DESC`

## Auto-update PWA (web/index.html)

| Parámetro | Valor | Razón |
|-----------|-------|-------|
| Version-check timeout | 8s (15s en 2G) | Era 2.5s — muy corto para datos móviles |
| Watchdog | 45s | Era 12s — CanvasKit.wasm tarda 15-25s en 3G |
| Slow-hint | visible tras 8s | El usuario sabe que carga, no que se colgó |

## Firestore rules (estado actual)

- `signedIn()` requerido para todo
- `businesses`: solo CEO puede crear/editar/borrar
- `users/{uid}`: solo propio usuario o CEO
- `memberships`: lectura solo de las propias (por email)
- `sales` + `fiado_payments`: append-only para no-CEO
- `sales.create`: valida `userId == request.auth.uid`
- Default deny

**Pendiente:** activar `canAccessBusiness()` con `businessIds[]` para aislamiento completo por negocio — las reglas ya tienen la función lista.
