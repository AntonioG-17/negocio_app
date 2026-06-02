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

## Auto-actualización (el usuario NO debe refrescar ni reinstalar nada)

`web/index.html` tiene un loader que hace updates 100% automáticos:
- Cada build de Flutter genera un `serviceWorkerVersion` nuevo.
- Al abrir, el loader baja `flutter_bootstrap.js` con URL única (`?_=timestamp`,
  `cache:'no-store'`) → siempre ve la versión real de la red.
- Si la versión cambió: borra todos los caches (Cache Storage), desregistra el
  Service Worker, guarda la versión nueva y hace `location.reload()` UNA vez
  (guardado en `sessionStorage._reloaded_for` para no entrar en loop).
- **Clave:** todos los scripts se cargan con `?v=<version>` (incluido
  `quagga.min.js` y `scanner_bridge.js`). Sin esto, el header `immutable` de
  `firebase.json` (`max-age=31536000`) cachea los `.js` de nombre fijo por 1 año
  y el usuario queda pegado en código viejo. Borrar el Cache Storage NO limpia
  el caché HTTP del disco; solo una URL nueva (`?v=`) lo busta.

**Si alguna vez queda pegado en una versión vieja** (p.ej. tras cambiar este
loader): una sola vez, quitar la PWA de la pantalla de inicio y volver a
agregarla (limpia el caché HTTP del disco). De ahí en adelante es automático.

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

## Scanner de código de barras (web/PWA en Safari iOS)

**Motor:** Quagga2 (`web/quagga.min.js`, bundleado local), NO html5-qrcode/ZXing.
ZXing falla decodificando códigos 1D borrosos/en ángulo en Safari iOS; Quagga2
está hecho para 1D (EAN/UPC/Code128/39) y tolera mucho mejor imágenes imperfectas.

**Arquitectura (bridge JS ↔ Dart):**
- `web/scanner_bridge.js` — overlay full-screen, init de Quagga, beep + vibración
  al detectar, línea de mira roja, hint de distancia (~15 cm).
- `lib/core/scanner/web_scanner_bridge.dart` — bindings `dart:js_interop`:
  `showScanTrigger` / `hideScanTrigger` / `startWebScanner` / `stopWebScanner`.
- `web/index.html` carga `quagga.min.js` + `scanner_bridge.js`.

**Truco clave para iOS (getUserMedia exige gesto DOM real):**
`showScanTrigger(x,y,w,h,...)` coloca un `<button>` HTML transparente EXACTAMENTE
encima del botón Flutter de escanear. Se pre-arma en `initState` (POS) o al activar
el switch de código de barras (inventario), así el PRIMER toque va directo al botón
HTML y Safari reconoce el gesto. El `AudioContext` del beep se prepara en ese click.

**Config Quagga relevante:** `numOfWorkers: 0` (single-thread, evita worker-blobs
que rompen en Safari), `halfSample: true`, `patchSize: 'medium'`, `area` central,
resolución `1280x720 ideal`, rechazo de lecturas con `avgError > 0.20`.

**Pantallas que escanean:** POS (`pos_screen.dart`) e inventario (`product_form_screen.dart`).

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
**Hoja "Fiados":** Cliente, Teléfono, Deuda actual (solo deudores) + TOTAL POR COBRAR  
**Hoja "Pagos fiados":** Fecha, Hora, Cliente, Monto, Nota (del periodo) + TOTAL PAGADO

- Las hojas de fiados solo aparecen si hay datos. Se arman desde `reportClientsProvider`
  y `reportFiadoPaymentsProvider`. El botón de exportar hoy se muestra si hay ventas en
  el periodo (los fiados viajan junto al export).
- Cada `FiadoPayment` guarda `clientName` denormalizado → el historial de pagos sobrevive
  aunque se borre el cliente.

## Rendimiento — lecturas server-side

Las ventas y pagos se filtran por fecha en el SERVIDOR (no se descarga toda la
colección y se filtra en el cliente, que se ponía lento/se congelaba al crecer):
- `todaySalesProvider` (dashboard): `where(businessId).where(createdAt >= hoy).orderBy(createdAt desc)`
- `reportSalesProvider` y `reportFiadoPaymentsProvider`: igual, por periodo.

Esto requiere índices compuestos en Firestore, definidos en `firestore.indexes.json`
y desplegados con `firebase deploy --only firestore:indexes`:
- `sales`: businessId ASC + createdAt DESC
- `fiado_payments`: businessId ASC + createdAt DESC

Si agregas una query con `where(igualdad) + where(rango/otro campo)` o
`where + orderBy(otro campo)`, añade el índice acá y vuelve a desplegar (si no,
Firestore rechaza la query). `firebase.json` tiene la sección `firestore`.

## Integridad de datos

- **Código de barras único:** `product_form` valida antes de guardar que ningún otro
  producto use el mismo código (si no, el escáner solo encontraría el primero).
- **Stock sin sobreventa:** `POSNotifier.checkout` usa una transacción Firestore que
  re-lee el stock real y aborta si el carrito supera lo disponible (mensaje específico
  "Stock insuficiente de X (quedan N)"). Nunca queda stock negativo.

## Activación de trabajadores

- Campo `isActive: bool` en `users/{uid}` (default `true` al crear)
- Admin puede activar/desactivar cada trabajador con un switch en el Panel Equipo
- Si `isActive == false`:
  - Login rechazado con error "Cuenta desactivada. Contacta al administrador"
  - Si ya estaba dentro de la app: el router detecta el cambio en tiempo real via stream y cierra sesión automáticamente (microtask logout)
- Trabajadores inactivos se ven en gris con chip "Inactivo" en el panel del admin
- La lista de trabajadores muestra activos e inactivos (el admin ve a todos)

## Ventas individuales por rol

- Trabajadores: dashboard muestra solo sus propias ventas del día
- Admin: dashboard muestra el total del día de TODO el negocio (todos los trabajadores + él mismo)
- Cada venta en Firestore guarda `userId` + `userName` → el Excel refleja quién hizo cada venta

## CEO Panel — flujo actual

- "Nuevo negocio" solo pide el nombre (sin creación de admin obligatoria)
- Tarjeta de negocio es tappeable → entra al **CEO Preview** del negocio

## CEO Preview (modo solo lectura) — implementado

El CEO toca un negocio en su panel y entra a verlo en **modo solo lectura**, para
monitorear lo que hacen admins/trabajadores.

- **Detección:** `isCeoPreviewProvider` = rol CEO + `selectedBusinessProvider != null`.
  Al tocar un negocio se setea `selectedBusinessProvider` y se navega a `/dashboard`.
- **Qué ve:** Dashboard, Inventario, Fiados y Reportes del negocio (barra de menú
  CEO sin "Vender"). Puede descargar Excel y ver el historial por día.
- **Solo lectura:** se ocultan TODAS las acciones de escritura — sin POS (vender),
  sin FAB de agregar producto/cliente, sin editar productos, sin registrar pago,
  sin eliminar cliente, sin panel de equipo.
- **Salir:** flecha "atrás" en el AppBar del dashboard (título "Vista CEO") →
  limpia `selectedBusinessProvider` y vuelve a `/ceo`.
- **Router:** cuando el CEO está en preview, se permiten `/dashboard /inventory
  /fiados /reports` (+ `/ceo`); se bloquean `/pos /inventory/add /inventory/edit
  /admin-panel`. Sin negocio seleccionado, el CEO solo accede a `/ceo`.
- Funciona porque las reglas de Firestore están abiertas (el CEO lee datos de
  cualquier negocio); los providers ya consultan por `selectedBusiness.id`.

## Checkout — pago en efectivo y vuelto

- Al elegir "Efectivo" y confirmar, tras las validaciones se pide "¿Con cuánto paga?"
  con cálculo de vuelto en vivo (botón "Pago justo" rellena el total). Solo se puede
  "Cobrar" si el monto ≥ total.
- El vuelto se muestra grande en el diálogo de éxito y NO se cierra solo: el botón dice
  "Listo, vuelto entregado" para confirmar la entrega.

## Convención de pop-ups (UX)

TODOS los diálogos y bottom sheets son no-descartables tocando afuera
(`barrierDismissible: false` en `showDialog`; `isDismissible: false` + `enableDrag: false`
en `showModalBottomSheet`). Solo se cierran con sus botones internos. Las hojas de
búsqueda/selección llevan un botón "Cerrar" visible. Mantener esta convención al agregar
nuevos pop-ups.

## Guardas contra doble-submit (operaciones de dinero)

- Checkout (`_confirmSale`) y registro de pago usan un flag síncrono (`_submitting`/`paying`)
  seteado ANTES del primer `await`, porque un doble-tap rápido dispara dos veces antes de
  que el botón se redibuje deshabilitado → sin la guarda se duplicaba la venta / quedaba
  deuda negativa.
- El sobrepago de fiado está validado en la UI (no puede superar la deuda).

## Por implementar

- CEO preview mode: navegar cualquier negocio en modo lectura (ver ventas + inventario, descargar Excel)
- Al entrar al negocio desde CEO panel: poder agregar admin/trabajadores a ese negocio
