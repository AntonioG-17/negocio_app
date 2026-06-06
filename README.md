# NegocioApp

Dashboard e inventario profesional para negocios físicos. Corre como **PWA web** instalable en iPhone y Android desde el navegador.

**URL live:** https://proyecto-app-negocio.web.app

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

La app se despliega como PWA en Firebase Hosting:

```bash
flutter build web --release && firebase deploy --only hosting
```

El PWA se actualiza automáticamente en cada visita sin que el usuario tenga que reinstalar nada.

## Desarrollo local

```bash
flutter pub get
flutter run -d chrome
```

## Documentación

- [Arquitectura del proyecto](docs/architecture.md)
- [Configuración de Firebase](docs/firebase-setup.md)

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
