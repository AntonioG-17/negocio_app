# NegocioApp

Dashboard e inventario profesional para negocios físicos. Corre como **PWA web** instalable en iPhone y Android desde el navegador.

**URL live:** https://proyecto-app-negocio.web.app  
**Versión:** v1.4.5

## Funcionalidades

- **Dashboard** — ventas del día filtradas por rol, alertas de stock bajo, fiados pendientes
- **Punto de Venta** — escaneo de código de barras (Quagga2), búsqueda manual, carrito, checkout con vuelto
- **Inventario** — CRUD de productos con/sin código de barras, control de stock
- **Fiados** — registro de clientes, historial de deudas y pagos
- **Reportes** — ventas por semana, mes y año con gráficos + exportar Excel
- **Panel CEO** — crear negocios y administradores, vista preview de cualquier negocio
- **Panel Admin** — gestionar trabajadores (crear, activar/desactivar, remover)
- **Multi-negocio** — una persona puede pertenecer a varios negocios con distintos roles

## Roles

| Rol | Acceso |
|-----|--------|
| **CEO** | Panel CEO: crear negocios y admins, ver cualquier negocio en modo lectura |
| **Admin** | Dashboard (todas las ventas), inventario, POS, fiados, reportes, panel equipo |
| **Trabajador** | Dashboard (solo sus ventas) + POS |

## Stack

Flutter 3.44 + Firebase (Firestore + Auth + Hosting) + Riverpod + go_router + Quagga2

## Despliegue

```bash
flutter build web --release --no-source-maps
firebase deploy
```

La app se actualiza automáticamente — el usuario nunca tiene que refrescar ni reinstalar.  
Resistente a WiFi/datos lentos: timeout de 8s para verificar versión (15s en 2G), watchdog de 45s, caché offline con Firestore persistence.

## Desarrollo local

```bash
flutter pub get
flutter run -d chrome
```

## Documentación

- [Arquitectura del proyecto](docs/architecture.md)
- [Configuración de Firebase](docs/firebase-setup.md)
- [Templates de email](docs/email-templates.md)

## Estructura

```
lib/
├── features/
│   ├── auth/          # Login, membresías multi-negocio, recuperación de contraseña
│   ├── ceo/           # Panel CEO, vista preview de negocios
│   ├── admin/         # Panel de equipo (trabajadores)
│   ├── dashboard/     # Stats diarios por rol
│   ├── inventory/     # Productos y stock
│   ├── pos/           # Punto de venta y checkout
│   ├── fiados/        # Clientes y deudas
│   └── reports/       # Reportes, gráficos y exportar Excel
├── core/
│   ├── scanner/       # Bridge JS↔Dart para escáner Quagga2
│   ├── theme/
│   └── utils/
web/
├── quagga.min.js      # Motor de escaneo 1D (local, sin CDN)
└── scanner_bridge.js  # Overlay de cámara + beep + botón HTML para iOS
```
