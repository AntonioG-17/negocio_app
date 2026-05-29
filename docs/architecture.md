# Arquitectura del Proyecto

## Stack tecnologico

| Capa | Tecnologia | Version |
|---|---|---|
| Framework | Flutter | 3.44+ |
| Estado | Riverpod | 2.6+ |
| Navegacion | go_router | 15+ |
| Backend | Firebase (Auth + Firestore) | — |
| Escaner | mobile_scanner | 7+ |
| Graficos | fl_chart | 0.71+ |
| Fuentes | Google Fonts (Inter) | — |

## Estructura de carpetas

```
lib/
├── main.dart                    # Punto de entrada
├── app.dart                     # Router + Shell + MaterialApp
├── firebase_options.dart        # Generado por flutterfire configure
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart   # Nombres de colecciones Firestore, constantes
│   ├── theme/
│   │   └── app_theme.dart       # Tema oscuro profesional
│   └── utils/
│       └── formatters.dart      # Formato de fechas y moneda
│
└── features/
    ├── auth/
    │   ├── models/business_model.dart
    │   ├── providers/auth_provider.dart    # Login, registro, seleccion de negocio
    │   └── screens/
    │       ├── login_screen.dart
    │       └── business_select_screen.dart
    │
    ├── dashboard/
    │   ├── providers/dashboard_provider.dart   # Stats del dia
    │   └── screens/dashboard_screen.dart
    │
    ├── inventory/
    │   ├── models/product_model.dart
    │   ├── providers/inventory_provider.dart   # CRUD productos, stock
    │   └── screens/
    │       ├── inventory_screen.dart
    │       └── product_form_screen.dart        # Agregar/editar con escaneo
    │
    ├── pos/                          # Punto de Venta
    │   ├── models/
    │   │   ├── sale_model.dart
    │   │   └── cart_item.dart
    │   ├── providers/pos_provider.dart    # Carrito + checkout
    │   └── screens/
    │       ├── pos_screen.dart            # Escaneo + busqueda manual
    │       └── checkout_screen.dart       # Confirmar venta / fiado
    │
    ├── fiados/                       # Sistema de credito/deuda
    │   ├── models/client_model.dart
    │   ├── providers/fiados_provider.dart
    │   └── screens/
    │       ├── fiados_screen.dart
    │       └── client_detail_screen.dart  # Historial + agregar pago
    │
    └── reports/
        ├── providers/reports_provider.dart
        └── screens/reports_screen.dart
```

## Flujo de navegacion

```
/login
  └── (autenticado) → /select-business
        └── (negocio seleccionado) → /dashboard [Shell]
              ├── /dashboard
              ├── /pos
              │     └── /pos/checkout
              ├── /inventory
              │     ├── /inventory/add
              │     └── /inventory/edit/:id
              ├── /fiados
              │     └── /fiados/:clientId
              └── /reports
```

## Patron de estado (Riverpod)

- **StreamProvider** → datos en tiempo real de Firestore (productos, clientes, ventas del dia)
- **FutureProvider** → consultas puntuales (reportes, negocios del usuario)
- **StateProvider** → estado de UI simple (busqueda, periodo de reporte, negocio seleccionado)
- **AsyncNotifier** → operaciones con estado de carga (login, crear producto, checkout)
- **NotifierProvider** → estado del carrito de compras

## Offline

Firestore tiene persistencia offline nativa habilitada por defecto en Flutter.
Los datos se guardan localmente y se sincronizan automaticamente cuando hay conexion.

## Flujo de venta

1. Usuario escanea codigo de barras (camara)
2. Si se encuentra el producto → se agrega al carrito
3. Si no se encuentra → opcion de buscar manualmente
4. Desde el carrito → Checkout
5. Checkout: elegir efectivo o fiado
6. Si fiado → seleccionar cliente (o crear nuevo)
7. Al confirmar:
   - Se crea el documento Sale en Firestore
   - Se descuenta el stock de cada producto (batch write)
   - Si fiado → se aumenta la deuda del cliente
