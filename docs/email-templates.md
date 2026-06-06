# Templates de Email — Firebase Console

Pegar en: **Firebase Console → Authentication → Templates**

---

## Configuración general (hacer una sola vez)

1. **Nombre del remitente:** `NegocioApp`
2. **Dirección del remitente:** dejar la default de Firebase (`noreply@proyecto-app-negocio.firebaseapp.com`) o configurar dominio propio (ver sección al final)
3. **URL de acción personalizada:** `https://proyecto-app-negocio.web.app/recuperar`

---

## Template 1 — Restablecer contraseña

**Asunto:**
```
Restablecer contraseña — NegocioApp
```

**Cuerpo del mensaje (HTML):**

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Restablecer contraseña</title>
</head>
<body style="margin:0;padding:0;background-color:#0f1117;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#0f1117;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">

          <!-- Logo / Header -->
          <tr>
            <td align="center" style="padding-bottom:32px;">
              <div style="display:inline-block;background:linear-gradient(135deg,#6c63ff,#a78bfa);border-radius:16px;padding:14px 24px;">
                <span style="font-size:22px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">NegocioApp</span>
              </div>
            </td>
          </tr>

          <!-- Card -->
          <tr>
            <td style="background-color:#1a1d27;border-radius:20px;padding:40px 36px;border:1px solid #2a2d3a;">

              <!-- Icon -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding-bottom:24px;">
                    <div style="width:56px;height:56px;background:linear-gradient(135deg,#6c63ff22,#a78bfa22);border:1px solid #6c63ff44;border-radius:14px;display:inline-block;line-height:56px;text-align:center;font-size:24px;">
                      🔑
                    </div>
                  </td>
                </tr>

                <!-- Title -->
                <tr>
                  <td align="center" style="padding-bottom:12px;">
                    <h1 style="margin:0;font-size:22px;font-weight:700;color:#f0f0f5;letter-spacing:-0.3px;">
                      Restablecer contraseña
                    </h1>
                  </td>
                </tr>

                <!-- Body text -->
                <tr>
                  <td align="center" style="padding-bottom:32px;">
                    <p style="margin:0;font-size:15px;color:#8b8fa8;line-height:1.6;max-width:360px;">
                      Recibimos una solicitud para restablecer la contraseña de tu cuenta. Toca el botón para crear una nueva.
                    </p>
                  </td>
                </tr>

                <!-- CTA Button -->
                <tr>
                  <td align="center" style="padding-bottom:32px;">
                    <a href="%LINK%"
                       style="display:inline-block;background:linear-gradient(135deg,#6c63ff,#a78bfa);color:#ffffff;text-decoration:none;font-size:15px;font-weight:600;padding:14px 36px;border-radius:12px;letter-spacing:0.2px;">
                      Crear nueva contraseña
                    </a>
                  </td>
                </tr>

                <!-- Divider -->
                <tr>
                  <td style="border-top:1px solid #2a2d3a;padding-top:24px;padding-bottom:16px;">
                    <p style="margin:0;font-size:13px;color:#555870;line-height:1.5;text-align:center;">
                      Si no solicitaste restablecer tu contraseña, puedes ignorar este correo.<br>
                      El enlace expira en <strong style="color:#8b8fa8;">1 hora</strong>.
                    </p>
                  </td>
                </tr>

                <!-- Link fallback -->
                <tr>
                  <td style="padding-top:4px;">
                    <p style="margin:0;font-size:12px;color:#3d4055;text-align:center;line-height:1.5;">
                      Si el botón no funciona, copia este enlace en tu navegador:<br>
                      <span style="color:#6c63ff;word-break:break-all;">%LINK%</span>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding-top:28px;">
              <p style="margin:0;font-size:12px;color:#3d4055;">
                NegocioApp &nbsp;·&nbsp; Sistema de gestión de negocio
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## Template 2 — Invitación de nuevo usuario

Este email se envía cuando un admin o el CEO invita a alguien que no tiene cuenta.
Firebase usa el mismo template de "Restablecer contraseña" para esto — el asunto y
cuerpo se pueden personalizar en la misma sección.

Para diferenciarlo, crear una **acción en Cloud Function** es la forma correcta,
pero como aún no hay Cloud Functions en este proyecto, el template de abajo es
una versión mejorada que funciona para ambos casos (reset + invitación).

**Asunto alternativo sugerido para invitaciones:**
Como Firebase no puede distinguir el asunto entre reset e invite con el mismo template,
usar un asunto neutro que funcione en ambos contextos:

```
Configura tu acceso — NegocioApp
```

**Cuerpo (versión que cubre ambos casos):**

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Acceso a NegocioApp</title>
</head>
<body style="margin:0;padding:0;background-color:#0f1117;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#0f1117;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">

          <!-- Logo -->
          <tr>
            <td align="center" style="padding-bottom:32px;">
              <div style="display:inline-block;background:linear-gradient(135deg,#6c63ff,#a78bfa);border-radius:16px;padding:14px 24px;">
                <span style="font-size:22px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">NegocioApp</span>
              </div>
            </td>
          </tr>

          <!-- Card -->
          <tr>
            <td style="background-color:#1a1d27;border-radius:20px;padding:40px 36px;border:1px solid #2a2d3a;">
              <table width="100%" cellpadding="0" cellspacing="0">

                <!-- Icon -->
                <tr>
                  <td align="center" style="padding-bottom:24px;">
                    <div style="width:56px;height:56px;background:linear-gradient(135deg,#6c63ff22,#a78bfa22);border:1px solid #6c63ff44;border-radius:14px;display:inline-block;line-height:56px;text-align:center;font-size:24px;">
                      🔐
                    </div>
                  </td>
                </tr>

                <!-- Title -->
                <tr>
                  <td align="center" style="padding-bottom:12px;">
                    <h1 style="margin:0;font-size:22px;font-weight:700;color:#f0f0f5;letter-spacing:-0.3px;">
                      Configura tu contraseña
                    </h1>
                  </td>
                </tr>

                <!-- Body -->
                <tr>
                  <td align="center" style="padding-bottom:32px;">
                    <p style="margin:0;font-size:15px;color:#8b8fa8;line-height:1.6;max-width:360px;">
                      Usa el botón a continuación para establecer tu contraseña y acceder a la app.
                    </p>
                  </td>
                </tr>

                <!-- CTA -->
                <tr>
                  <td align="center" style="padding-bottom:32px;">
                    <a href="%LINK%"
                       style="display:inline-block;background:linear-gradient(135deg,#6c63ff,#a78bfa);color:#ffffff;text-decoration:none;font-size:15px;font-weight:600;padding:14px 36px;border-radius:12px;letter-spacing:0.2px;">
                      Configurar mi contraseña
                    </a>
                  </td>
                </tr>

                <!-- Divider -->
                <tr>
                  <td style="border-top:1px solid #2a2d3a;padding-top:24px;padding-bottom:16px;">
                    <p style="margin:0;font-size:13px;color:#555870;line-height:1.5;text-align:center;">
                      Si no esperabas este correo, puedes ignorarlo.<br>
                      El enlace expira en <strong style="color:#8b8fa8;">1 hora</strong>.
                    </p>
                  </td>
                </tr>

                <!-- Fallback link -->
                <tr>
                  <td style="padding-top:4px;">
                    <p style="margin:0;font-size:12px;color:#3d4055;text-align:center;line-height:1.5;">
                      Si el botón no funciona, copia este enlace:<br>
                      <span style="color:#6c63ff;word-break:break-all;">%LINK%</span>
                    </p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding-top:28px;">
              <p style="margin:0;font-size:12px;color:#3d4055;">
                NegocioApp &nbsp;·&nbsp; Sistema de gestión de negocio
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## Cómo aplicar en Firebase Console

1. Ir a [console.firebase.google.com](https://console.firebase.google.com) → proyecto `proyecto-app-negocio`
2. **Authentication → Templates** (ícono de sobre)
3. Seleccionar **"Restablecimiento de contraseña"**
4. Clic en el ícono de editar (lápiz)
5. Cambiar **Nombre del remitente** a `NegocioApp`
6. Cambiar el **Asunto** al texto de arriba
7. Activar la opción **"Personalizar plantilla de acción"** y pegar la URL: `https://proyecto-app-negocio.web.app/recuperar`
8. En el cuerpo, borrar el HTML existente y pegar el de arriba
9. Guardar

---

## Configurar remitente personalizado (opcional, requiere dominio propio)

Para que el email llegue desde `hola@tudominio.com` en vez de `noreply@...firebaseapp.com`:

1. Firebase Console → Authentication → Templates → clic en **"Personalizar dominio de correo"**
2. Agregar el dominio y verificar los registros DNS que Firebase indica (SPF, DKIM)
3. Una vez verificado, Firebase envía desde ese dominio

Sin dominio propio, el remitente seguirá siendo el de Firebase y es funcional — solo menos branded.
