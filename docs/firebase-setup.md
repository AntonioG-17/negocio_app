# Configuración de Firebase

> El proyecto Firebase `proyecto-app-negocio` ya está configurado y en producción en https://proyecto-app-negocio.web.app

---

## Proyecto en producción

- **Firebase project:** `proyecto-app-negocio`
- **Auth:** Email/Password habilitado
- **Firestore:** modo producción con reglas cerradas
- **Hosting:** caché agresivo para assets, sin caché para HTML/SW

---

## Setup desde cero (nuevo proyecto)

### 1. Crear proyecto en Firebase

1. [console.firebase.google.com](https://console.firebase.google.com) → Agregar proyecto
2. Desactivar Google Analytics si no se necesita

### 2. Activar servicios

**Authentication** → Sign-in method → Correo electrónico/Contraseña → Activar

**Firestore** → Crear base de datos → Modo producción → región más cercana

**Hosting** → Comenzar
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
```

### 3. Conectar Flutter

```bash
dart pub global activate flutterfire_cli
cd negocio_app
flutterfire configure   # genera lib/firebase_options.dart
```

### 4. URL de acción personalizada para emails

Firebase Console → Authentication → Templates → Restablecimiento de contraseña → editar → URL de acción personalizada:
```
https://proyecto-app-negocio.web.app/recuperar
```

Esto hace que el link del correo llegue a la página branded de la app en vez de la página genérica de Firebase.

### 5. Reglas de Firestore

```bash
firebase deploy --only firestore:rules
```

### 6. Índices de Firestore

```bash
firebase deploy --only firestore:indexes
```

Índices requeridos (`firestore.indexes.json`):
- `sales`: `businessId ASC + createdAt DESC`
- `fiado_payments`: `businessId ASC + createdAt DESC`

### 7. Desplegar

```bash
flutter build web --release --no-source-maps
firebase deploy
```

---

## Estructura de Firestore

```
users/{uid}
  email: string
  name: string
  businessId: string?         # legacy — campo original
  businessIds: string[]       # nuevo — array de todos los negocios del usuario
  isActive: bool
  role: string?               # legacy
  createdAt: Timestamp

businesses/{id}
  name: string
  ownerId: string             # uid del CEO
  createdAt: Timestamp

memberships/{id}
  email: string               # minúsculas — clave de búsqueda
  name: string
  businessId: string
  role: 'admin' | 'worker'
  isActive: bool
  createdAt: Timestamp

products/{id}
  businessId: string
  name: string
  barcode: string?
  price: number
  cost: number?
  stock: number
  minStock: number
  hasBarcode: bool
  category: string?
  createdAt: Timestamp
  updatedAt: Timestamp

sales/{id}
  businessId: string
  userId: string
  userName: string?
  items: [{productId, productName, quantity, price}]
  total: number
  paymentType: 'cash' | 'fiado' | 'card'
  clientId: string?
  clientName: string?
  createdAt: Timestamp

clients/{id}
  businessId: string
  name: string
  phone: string?
  totalDebt: number
  createdAt: Timestamp
  updatedAt: Timestamp

fiado_payments/{id}
  clientId: string
  clientName: string          # denormalizado — sobrevive si se borra el cliente
  businessId: string
  amount: number
  note: string?
  createdAt: Timestamp
```

---

## Cuenta CEO

El CEO se identifica por email en `AppConstants.ceoEmail`. La detección es client-side pero también está en Firestore rules server-side (`isCeo()` verifica `request.auth.token.email`). El perfil en `users/{uid}` se crea automáticamente en el primer login.

---

## Notas de producción

- **firebase_performance**: NO instalar en Flutter web sin configuración adicional en `index.html`. En v1.4.0 se instaló y causó que la app no cargara en ningún dispositivo — `setPerformanceCollectionEnabled()` lanza excepción en web sin el SDK de Firebase JS.
- **Firestore offline persistence**: habilitado en `main.dart` con try-catch. En modo privado del navegador, IndexedDB puede estar bloqueado — el try-catch evita que crashee.
- **SystemChrome.setPreferredOrientations**: no usar en `main()` para web — puede causar problemas de inicialización.
