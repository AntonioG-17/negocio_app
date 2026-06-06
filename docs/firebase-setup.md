# Configuración de Firebase

> **Nota:** El proyecto Firebase `proyecto-app-negocio` ya está configurado y en producción.
> Esta guía sirve para replicar el setup en un proyecto nuevo o para referencia.

## Proyecto en producción

- **Firebase project:** `proyecto-app-negocio`
- **URL hosting:** https://proyecto-app-negocio.web.app
- **Auth:** Email/Password habilitado
- **Firestore:** modo producción con reglas cerradas
- **Hosting:** configurado con caché agresivo para assets y sin caché para HTML

---

## Setup desde cero (nuevo proyecto)

### 1. Crear proyecto en Firebase

1. Ve a [console.firebase.google.com](https://console.firebase.google.com)
2. **Agregar proyecto** → asigna un nombre
3. Desactiva Google Analytics si no lo necesitas

### 2. Activar servicios

**Authentication**
1. Authentication → Comenzar → Sign-in method
2. Activa **Correo electrónico/Contraseña**
3. (Opcional pero recomendado) En la plantilla de "Restablecer contraseña", configurar la URL de acción personalizada a `https://tu-proyecto.web.app/recuperar` para usar la página branded de la app

**Firestore Database**
1. Firestore Database → Crear base de datos → Modo producción
2. Elige la región más cercana (ej. `us-central1`)

**Hosting**
1. Hosting → Comenzar
2. Instala Firebase CLI: `npm install -g firebase-tools`
3. `firebase login && firebase init hosting`

### 3. Conectar la app Flutter

```bash
dart pub global activate flutterfire_cli
cd negocio_app
flutterfire configure
```

Esto regenera `lib/firebase_options.dart`.

### 4. Reglas de Firestore

Las reglas están en `firestore.rules` y se despliegan con:

```bash
firebase deploy --only firestore:rules
```

Estado actual de las reglas:
- Todo acceso requiere usuario autenticado
- Negocios: solo el CEO puede crear/editar/borrar (validado por email en el cliente; las reglas validan auth)
- Default deny para paths no mapeados

### 5. Índices de Firestore

Los índices compuestos están en `firestore.indexes.json`. Desplegar con:

```bash
firebase deploy --only firestore:indexes
```

Índices requeridos:
- `sales`: `businessId ASC + createdAt DESC`
- `fiado_payments`: `businessId ASC + createdAt DESC`

### 6. Desplegar

```bash
flutter build web --release
firebase deploy --only hosting
```

O todo junto:

```bash
flutter build web --release && firebase deploy
```

---

## Estructura de Firestore

```
users/{uid}
  role: 'ceo' | 'admin' | 'worker'   (legacy, para migración)
  businessId: string                  (legacy, para migración)
  isActive: bool

businesses/{id}
  name: string
  ownerId: string   (uid del CEO)
  createdAt: Timestamp

memberships/{id}
  email: string        (minúsculas — clave de búsqueda)
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
  userName: string
  items: [{productId, name, price, quantity, subtotal}]
  total: number
  paymentType: 'efectivo' | 'fiado'
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
  clientName: string   (denormalizado — sobrevive si se borra el cliente)
  businessId: string
  amount: number
  note: string?
  createdAt: Timestamp
```

---

## Cuenta CEO

El CEO se identifica por email en `AppConstants.ceoEmail`. No requiere un rol especial en Firestore; la detección es client-side. El perfil en `users/{uid}` se crea automáticamente en el primer login.
