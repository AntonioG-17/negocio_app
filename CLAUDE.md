# NegocioApp — Contexto del proyecto

App de inventario y dashboard para negocio físico, desplegada como **PWA web** en Firebase Hosting.

**URL live:** https://proyecto-app-negocio.web.app  
**GitHub:** https://github.com/AntonioG-17/negocio_app  
**Carpeta local:** `/Users/antonioquilodrangeldes/Desktop/Carpeta Idea Proyectos/negocio_app/`  
**Versión actual:** v1.4.5  
**Firebase project:** `proyecto-app-negocio`

## Stack

Flutter 3.44 + Firebase (Firestore + Auth + Hosting) + Riverpod + go_router + Quagga2

## Despliegue

```bash
flutter build web --release --no-source-maps && firebase deploy
```

La app se instala como PWA desde Safari iOS → "Agregar a pantalla de inicio".  
Se actualiza automáticamente — el usuario nunca tiene que reinstalar ni refrescar.

## Sistema de roles

| Rol | Acceso | Creado por |
|-----|--------|------------|
| **CEO** | Panel CEO: crear negocios + admins, ver cualquier negocio en modo lectura | Email hardcodeado |
| **Admin** | Dashboard (todas las ventas), inventario, POS, fiados, reportes, panel equipo | CEO |
| **Trabajador** | Dashboard (solo sus ventas) + POS | Admin |

- CEO se detecta por email = `AppConstants.ceoEmail` (antonio.geldes1701@gmail.com)
- No hay registro público. Solo login.

## Firestore collections

```
users/{uid}          → email, name, businessId (legacy), businessIds[], isActive
businesses/{id}      → name, ownerId, createdAt
memberships/{id}     → email, name, businessId, role, isActive, createdAt
products/{id}        → businessId, name, barcode?, price, cost?, stock, minStock, hasBarcode
sales/{id}           → businessId, userId, userName, items[], total, paymentType, clientId?, clientName?, createdAt
clients/{id}         → businessId, name, phone?, totalDebt
fiado_payments/{id}  → clientId, clientName, businessId, amount, note?, createdAt
```

## Cuenta CEO

- **Email:** antonio.geldes1701@gmail.com (ya existe en Firebase Auth)
- **UID:** hvWgAvCj53YoFsQn4Yl31UhKrG73
- El perfil CEO se crea automáticamente en el primer login

## Scanner de código de barras (web/PWA en Safari iOS)

**Motor:** Quagga2 (`web/quagga.min.js`, bundleado local).

**Arquitectura (bridge JS ↔ Dart):**
- `web/scanner_bridge.js` — overlay full-screen, init Quagga, beep + vibración, línea de mira
- `lib/core/scanner/web_scanner_bridge.dart` — bindings `dart:js_interop`

**Truco clave para iOS:** `showScanTrigger` coloca un `<button>` HTML transparente encima del botón Flutter. El primer toque va al elemento HTML y Safari reconoce el gesto para `getUserMedia`.

**Config Quagga:** `numOfWorkers: 0` (single-thread, evita worker-blobs que rompen en Safari), `halfSample: true`, rechazo de lecturas con `avgError > 0.20`.

**Pantallas que escanean:** POS (`pos_screen.dart`) e inventario (`product_form_screen.dart`).

**Lifecycle:** `POSScreen` implementa `WidgetsBindingObserver` — detiene la cámara al ir a segundo plano y la re-arma al volver.

## Módulos implementados

- Auth: login, recuperación de contraseña, membresías multi-negocio, cambio de contraseña
- Dashboard: ventas del día filtradas por rol, alertas de stock bajo, fiados pendientes
- Inventario: CRUD productos + escaneo, validación de código de barras único
- POS: escaneo + búsqueda + carrito + checkout (efectivo con vuelto, fiado)
- Fiados: clientes + historial + pagos (transacción segura, deuda nunca negativa)
- Reportes: gráficos semana/mes/año + exportar Excel (4 hojas)
- CEO Panel: crear negocios + admins, vista preview modo lectura de cualquier negocio
- Admin Panel: crear/remover/activar-desactivar trabajadores
- Página branded `/recuperar`: reset password + invitaciones (sin diseño de Firebase)

## Permisos por rol — Inventario

| Acción | CEO | Admin | Trabajador |
|--------|-----|-------|------------|
| Ver inventario | preview | ✓ | ✓ (solo lectura) |
| Agregar producto | — | ✓ | ✗ |
| Editar/eliminar producto | — | ✓ | ✗ |

## Modelo de membresías

Colección `memberships`: `{ email(minúsculas), name, businessId, role(admin|worker), isActive, createdAt }`.

- `userMembershipsProvider`: **StreamProvider** — membresías activas en tiempo real. Si el admin desactiva a un worker mid-session, el router lo expulsa automáticamente.
- Al invitar: si el correo no tiene cuenta, se crea con clave temporal + se envía link de recuperación.
- `users/{uid}.businessIds[]`: array mantenido automáticamente al invitar/migrar, usado por Firestore rules para aislamiento.
- Migración legacy: `_migrateLegacyMembership` convierte `users/{uid}.businessId+role` al modelo nuevo (idempotente).

## CEO Preview (modo solo lectura)

El CEO toca un negocio → entra en modo lectura (dashboard, inventario, fiados, reportes). Sin POS, sin FAB, sin editar. Salir con la flecha "atrás" del AppBar.

## Checkout — pago en efectivo y vuelto

- Efectivo: pide "¿Con cuánto paga?" con vuelto en vivo. Solo cobra si monto ≥ total.
- Vuelto se muestra en diálogo de éxito que no se cierra solo.
- Transacción Firestore: re-lee stock real, aborta si insuficiente → nunca stock negativo.
- Carrito validado antes de `AsyncLoading` para evitar race condition con carrito vacío.

## Fiados — integridad de deuda

- `addPayment` usa transacción Firestore que re-lee la deuda real antes de decrementar.
- Si el pago supera la deuda actual, aborta con mensaje claro → deuda nunca negativa.
- `clientName` denormalizado en pagos → historial sobrevive si se borra el cliente.

## Convención de pop-ups (UX)

Todos los diálogos y bottom sheets: `barrierDismissible: false`, `isDismissible: false`, `enableDrag: false`. Solo se cierran con sus botones internos.

## Guardas contra doble-submit

Checkout y registro de pago usan flag síncrono (`_submitting`/`paying`) seteado ANTES del primer `await`. Sin esto, doble-tap rápido duplica la venta.

## Auto-actualización PWA

`web/index.html` actualiza la app automáticamente:
1. Baja `flutter_bootstrap.js?_=timestamp` (sin caché) con timeout de 8s (15s en conexión lenta)
2. Si versión cambió: limpia caches y Service Worker, carga versión nueva sin recargar
3. Scripts con `?v=<version>` para bustar el caché HTTP de disco
4. Watchdog de 45s: si Flutter no renderiza, limpia caché una vez y recarga (era 12s — muy corto para CanvasKit.wasm en 3G)
5. Hint visible de "Conexión lenta" tras 8s sin que cargue

## Offline

`FirebaseFirestore.instance.settings` con `persistenceEnabled: true` y caché ilimitado. La app carga y muestra datos aunque no haya internet; sincroniza al volver la conexión. Envuelto en try-catch por si el navegador bloquea IndexedDB (modo privado).

## Rendimiento — lecturas server-side

Ventas y pagos filtrados por fecha en el servidor:
- `sales`: índice `businessId ASC + createdAt DESC`
- `fiado_payments`: índice `businessId ASC + createdAt DESC`

## Integridad de datos

- **Código de barras único**: `product_form` valida localmente contra `productsStreamProvider`
- **Stock sin sobreventa**: transacción Firestore en checkout re-lee stock real
- **Deuda nunca negativa**: transacción Firestore en `addPayment` re-lee deuda real
- **Ventas append-only**: Firestore rules prohíben update/delete en `sales` y `fiado_payments` para no-CEO
- **Sales.userId validado**: Firestore rules verifican `userId == request.auth.uid` en create

## Firestore rules (estado actual)

- Todo acceso requiere sesión (`signedIn()`)
- Negocios: solo el CEO puede crear/editar/borrar
- `users/{uid}`: solo el propio usuario o CEO puede leer/escribir
- `memberships`: cada usuario solo lee las suyas (por email)
- `sales` y `fiado_payments`: append-only para no-CEO
- `sales.create`: valida `userId == request.auth.uid`
- Default deny para paths no mapeados
- **Pendiente**: aislamiento por negocio vía `businessIds` — las reglas tienen la función `canAccessBusiness()` lista pero se activará cuando todos los usuarios tengan el array poblado

## Activación de trabajadores en tiempo real

- `userMembershipsProvider` es `StreamProvider` → detecta cambios en tiempo real
- Listener en `app.dart` limpia `selectedBusiness/Membership` si la membresía activa desaparece
- Worker desactivado es expulsado automáticamente sin necesitar logout

## Página branded /recuperar

Ruta pública (`/recuperar`) para reset de contraseña e invitaciones. Usa `FirebaseAuthException.code` para distinguir links expirados vs errores genéricos.

**Requiere una vez en Firebase Console:** plantilla de reset → URL de acción personalizada → `https://proyecto-app-negocio.web.app/recuperar`

## Email templates

Los templates HTML para Firebase Console están en `docs/email-templates.md`.  
**Nota:** Firebase Spark (plan gratuito) no permite editar el cuerpo del email — solo nombre del remitente y asunto. El link siempre llega a `/recuperar` via `ActionCodeSettings` en el código.

## Excel — estructura actual

**Hoja "Resumen":** Periodo, Exportado, Ingresos totales, Total ventas, Cobrado, Fiados  
**Hoja "Ventas":** Fecha, Hora, Trabajador, Productos, Total, Tipo de pago, Cliente  
**Hoja "Fiados":** Cliente, Teléfono, Deuda actual (solo deudores) + TOTAL POR COBRAR  
**Hoja "Pagos fiados":** Fecha, Hora, Cliente, Monto, Nota (del periodo) + TOTAL PAGADO

## Por implementar

- Aislamiento completo por negocio en Firestore rules (activar `canAccessBusiness()` cuando todos los usuarios tengan `businessIds` poblado — requiere migración o trigger)
- Desde CEO panel → gestionar equipo de un negocio directamente
- Validación server-side de que solo admins pueden invitar (requiere Cloud Functions — plan Blaze)
