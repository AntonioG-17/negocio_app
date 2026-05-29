# NegocioApp

Dashboard e inventario profesional para negocios fisicos. iOS + Android.

## Funcionalidades

- **Dashboard** — ventas del dia, alertas de stock bajo, fiados pendientes
- **Punto de Venta** — escaneo de codigo de barras, busqueda manual, carrito
- **Inventario** — productos con o sin codigo de barras, control de stock
- **Fiados** — registro de clientes, historial de deudas y pagos
- **Reportes** — ventas por semana, mes y año con graficos

## Stack

Flutter + Firebase (Firestore + Auth) + Riverpod

## Configuracion inicial

### 1. Instalar dependencias

```bash
flutter pub get
```

### 2. Configurar Firebase

Ver [docs/firebase-setup.md](docs/firebase-setup.md) para instrucciones completas.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 3. Ejecutar

```bash
flutter run
```

## Documentacion

- [Arquitectura del proyecto](docs/architecture.md)
- [Configuracion de Firebase](docs/firebase-setup.md)

## Estructura

```
lib/
├── features/
│   ├── auth/          # Login, registro, seleccion de negocio
│   ├── dashboard/     # Stats diarios
│   ├── inventory/     # Productos y stock
│   ├── pos/           # Punto de venta y checkout
│   ├── fiados/        # Clientes y deudas
│   └── reports/       # Reportes y graficos
```
