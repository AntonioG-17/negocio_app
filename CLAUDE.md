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
- Admin/trabajadores se agregan separado (parte del CEO preview mode pendiente)
- Tarjeta de negocio tiene flecha `>` (hint de que se podrá entrar en preview mode)

## Por implementar

- CEO preview mode: navegar cualquier negocio en modo lectura (ver ventas + inventario, descargar Excel)
- Al entrar al negocio desde CEO panel: poder agregar admin/trabajadores a ese negocio
