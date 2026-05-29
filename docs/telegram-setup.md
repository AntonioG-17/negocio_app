# Configurar recordatorios por Telegram (GRATIS)

## Por qué Telegram

- 100% gratis, sin limite de mensajes
- Open source
- El cliente solo necesita la app Telegram (gratuita)
- Funciona en iOS, Android y web

## Paso 1 — Crear el bot (2 minutos)

1. Abre Telegram y busca **@BotFather**
2. Escribe `/newbot`
3. Pon un nombre: ej. `Don Filomena Recordatorios`
4. Pon un username (debe terminar en "bot"): ej. `donfilomenabot`
5. BotFather te da el **token**: `7123456789:AAFxxxxxxxxxx`

## Paso 2 — Configurar en la app

Edita el archivo:
```
lib/core/config/telegram_config.dart
```

Reemplaza el placeholder:
```dart
class TelegramConfig {
  static const String botToken = '7123456789:AAFxxxxxxxxxx'; // tu token aqui
}
```

## Paso 3 — Cada cliente obtiene su Chat ID

El cliente necesita hacer esto UNA SOLA VEZ:

1. El cliente abre Telegram y busca tu bot (ej. `@donfilomenabot`)
2. Presiona **Start** / escribe `/start`
3. El bot no responde aun (es normal)
4. El cliente va a esta URL en su navegador y copia el numero `id`:
   ```
   https://api.telegram.org/bot[TU_TOKEN]/getUpdates
   ```
   Busca `"chat":{"id":XXXXXXXXX}` — ese numero es el Chat ID

5. El cliente le dice ese numero al vendedor
6. El vendedor lo ingresa al crear o editar el cliente en la app

## Alternativa mas facil (opcional)

Puedo agregar un comando `/start` al bot que responda automaticamente
con el Chat ID del cliente. Avisame si quieres que lo implemente.

## Como funciona el recordatorio

1. Vendedor entra al detalle del cliente
2. Toca **"Enviar recordatorio por Telegram"**
3. El cliente recibe este mensaje en Telegram:

```
👋 Hola Juan

Te recordamos que tienes una deuda pendiente de
$10.800 en Don Filomena.

Por favor comunícate con nosotros para coordinar el pago.

¡Muchas gracias! 🙏
```

## Costo

$0. Gratis para siempre.
