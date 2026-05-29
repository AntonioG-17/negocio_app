# Configuracion de Firebase

## Paso 1 — Crear proyecto en Firebase

1. Ve a [console.firebase.google.com](https://console.firebase.google.com)
2. Clic en **"Agregar proyecto"**
3. Nombre: `negocio-app` (o el que prefieras)
4. Desactiva Google Analytics si no lo necesitas → **Crear proyecto**

## Paso 2 — Activar servicios

### Authentication
1. En el menu izquierdo: **Authentication → Comenzar**
2. En la pestaña **Sign-in method**
3. Activa **Correo electronico/Contrasena**

### Firestore Database
1. En el menu izquierdo: **Firestore Database → Crear base de datos**
2. Selecciona **Comenzar en modo de produccion**
3. Elige la region mas cercana (ej. `us-central1`)

## Paso 3 — Reglas de Firestore

Ve a **Firestore → Reglas** y pega esto:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Solo el dueno puede acceder a su negocio
    match /businesses/{businessId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.ownerId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.ownerId;
    }

    // Productos: acceso si el negocio pertenece al usuario autenticado
    match /products/{productId} {
      allow read, write: if request.auth != null;
    }

    match /sales/{saleId} {
      allow read, write: if request.auth != null;
    }

    match /clients/{clientId} {
      allow read, write: if request.auth != null;
    }

    match /fiado_payments/{paymentId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> Nota: Estas reglas permiten acceso a cualquier usuario autenticado. Para produccion, personaliza segun tus necesidades.

## Paso 4 — Conectar la app Flutter

### Instalar FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### Configurar (desde la carpeta del proyecto)

```bash
cd negocio_app
flutterfire configure
```

- Selecciona tu proyecto de Firebase
- Selecciona las plataformas: **android, ios**
- Esto genera automaticamente `lib/firebase_options.dart`

## Paso 5 — Configuracion Android adicional

Abre `android/app/build.gradle.kts` y verifica que `minSdk` sea al menos **21**:

```kotlin
android {
    defaultConfig {
        minSdk = 21
    }
}
```

## Paso 6 — Ejecutar la app

```bash
flutter run
```

## Estructura de Firestore

```
businesses/
  {id}/ → name, ownerId, createdAt

products/
  {id}/ → businessId, name, barcode?, price, cost?, stock, minStock, category?, hasBarcode, createdAt, updatedAt

sales/
  {id}/ → businessId, userId, items[], total, paymentType, clientId?, clientName?, createdAt

clients/
  {id}/ → businessId, name, phone?, totalDebt, createdAt, updatedAt

fiado_payments/
  {id}/ → clientId, businessId, amount, note?, createdAt
```
