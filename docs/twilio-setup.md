# Configurar SMS con Twilio

## Por qué Twilio

Twilio permite enviar SMS directamente desde la app sin redirigir a WhatsApp ni otra app.
El vendedor presiona "Enviar recordatorio" y el SMS llega al telefono del cliente automaticamente.

## Costo

- Cuenta gratuita: $15 USD de credito (suficiente para ~1900 SMS a Chile)
- Despues: ~$0.0079 USD por SMS (~$7 CLP)

## Paso 1 — Crear cuenta Twilio

1. Ve a [twilio.com](https://www.twilio.com/try-twilio)
2. Regístrate con tu email
3. Verifica tu numero de telefono

## Paso 2 — Obtener numero Twilio

1. En el panel: **Phone Numbers → Get a number**
2. Elige un numero (prefiere uno con capacidad SMS)
3. Anota el numero (formato: +1XXXXXXXXXX)

## Paso 3 — Obtener credenciales

En el panel principal de Twilio:
- **Account SID**: empieza con `AC...`
- **Auth Token**: clic en el ojo para verlo

## Paso 4 — Configurar en la app

Edita el archivo:
```
lib/core/config/twilio_config.dart
```

Reemplaza los placeholders:
```dart
class TwilioConfig {
  static const String accountSid = 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  static const String authToken = 'tu_auth_token_aqui';
  static const String fromPhone = '+1XXXXXXXXXX'; // tu numero Twilio
}
```

## Paso 5 — Verificar numero del cliente (trial)

En la cuenta trial de Twilio, solo puedes enviar SMS a numeros verificados.

1. Panel Twilio → **Verify a number**
2. Agrega el numero del cliente para pruebas
3. En cuenta de pago (upgrade) puedes enviar a cualquier numero

## Formato del telefono en la app

El servicio agrega automaticamente el codigo de pais +56 (Chile) si el numero no lo tiene.

Ejemplos validos:
- `912345678` → se convierte a `+56912345678`
- `+56912345678` → se usa tal cual
- `56912345678` → se convierte a `+56912345678`

## Nota de seguridad

Para produccion, las credenciales no deben estar en el codigo fuente.
La arquitectura ideal es:

```
App Flutter → Firebase Cloud Function → Twilio API
```

El Cloud Function actua como proxy seguro. Implementarlo cuando el negocio
necesite mayor seguridad.
