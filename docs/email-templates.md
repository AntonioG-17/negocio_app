# Templates de Email — Firebase Console

Pegar en: **Firebase Console → Authentication → Templates**

---

## Configuración (hacer una sola vez)

1. Ir a [console.firebase.google.com](https://console.firebase.google.com) → proyecto `proyecto-app-negocio`
2. **Authentication → Templates** (ícono de sobre en el menú superior)
3. Seleccionar **"Restablecimiento de contraseña"** → ícono de lápiz (editar)
4. Cambiar **Nombre del remitente** a: `NegocioApp`
5. El **Correo del remitente** quedará como `noreply@proyecto-app-negocio.firebaseapp.com` — Firebase no permite cambiarlo sin un plan de pago con dominio propio. El nombre "NegocioApp" es lo que aparece visible en la bandeja de entrada.
6. Cambiar el **Asunto** y pegar el **HTML del cuerpo** según el template de abajo
7. En **"URL de acción personalizada"** pegar: `https://proyecto-app-negocio.web.app/recuperar`
8. Guardar

---

## Template — Restablecimiento de contraseña e invitaciones

Firebase usa el mismo template para ambos casos (reset de contraseña + invitación de nuevo usuario). El asunto y diseño cubren ambos casos de forma neutral y elegante.

**Asunto:**
```
Acceso a NegocioApp
```

**Cuerpo (HTML — pegar completo en Firebase Console):**

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
</head>
<body style="margin:0;padding:0;background-color:#111318;font-family:ui-sans-serif,-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#111318">
    <tr>
      <td align="center" style="padding:48px 16px 40px;">

        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">

          <!-- LOGO -->
          <tr>
            <td align="center" style="padding-bottom:36px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background:#7c6ef7;border-radius:14px;padding:12px 22px;">
                    <span style="font-size:20px;font-weight:700;color:#ffffff;letter-spacing:-0.4px;font-family:ui-sans-serif,-apple-system,sans-serif;">
                      NegocioApp
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CARD -->
          <tr>
            <td style="background-color:#1c1f2e;border-radius:18px;border:1px solid #252839;overflow:hidden;">

              <!-- ACCENT BAR -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td height="4" style="background:#7c6ef7;font-size:0;line-height:0;">&nbsp;</td>
                </tr>
              </table>

              <!-- CARD CONTENT -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="padding:40px 40px 36px;">

                    <!-- TITLE -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom:12px;">
                          <p style="margin:0;font-size:22px;font-weight:700;color:#ecedf5;letter-spacing:-0.4px;line-height:1.2;font-family:ui-sans-serif,-apple-system,sans-serif;">
                            Configura tu contraseña
                          </p>
                        </td>
                      </tr>

                      <!-- BODY TEXT -->
                      <tr>
                        <td style="padding-bottom:32px;">
                          <p style="margin:0;font-size:15px;color:#7f839e;line-height:1.65;font-family:ui-sans-serif,-apple-system,sans-serif;">
                            Recibimos una solicitud relacionada con tu cuenta en NegocioApp.
                            Usa el botón a continuación para establecer o restablecer tu contraseña
                            y acceder a la plataforma.
                          </p>
                        </td>
                      </tr>

                      <!-- CTA BUTTON -->
                      <tr>
                        <td style="padding-bottom:36px;">
                          <table role="presentation" cellpadding="0" cellspacing="0">
                            <tr>
                              <td style="background:#7c6ef7;border-radius:10px;">
                                <a href="%LINK%"
                                   style="display:block;padding:13px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;letter-spacing:0.1px;font-family:ui-sans-serif,-apple-system,sans-serif;white-space:nowrap;">
                                  Configurar contraseña &rarr;
                                </a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- DIVIDER -->
                      <tr>
                        <td height="1" style="background:#252839;font-size:0;line-height:0;padding-bottom:24px;">&nbsp;</td>
                      </tr>

                      <!-- EXPIRY NOTE -->
                      <tr>
                        <td style="padding-top:0;padding-bottom:20px;">
                          <p style="margin:0;font-size:13px;color:#515470;line-height:1.6;font-family:ui-sans-serif,-apple-system,sans-serif;">
                            Este enlace expira en <span style="color:#9b97c0;">1 hora</span>.
                            Si no esperabas este correo, puedes ignorarlo — tu cuenta permanece segura.
                          </p>
                        </td>
                      </tr>

                      <!-- LINK FALLBACK -->
                      <tr>
                        <td style="background:#161825;border-radius:8px;padding:14px 16px;">
                          <p style="margin:0 0 4px;font-size:11px;color:#3e4157;font-weight:600;text-transform:uppercase;letter-spacing:0.6px;font-family:ui-sans-serif,-apple-system,sans-serif;">
                            Si el botón no funciona, copia este enlace:
                          </p>
                          <p style="margin:0;font-size:12px;color:#7c6ef7;word-break:break-all;line-height:1.5;font-family:ui-monospace,'SF Mono','Fira Code',monospace;">
                            %LINK%
                          </p>
                        </td>
                      </tr>

                    </table>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td align="center" style="padding-top:28px;">
              <p style="margin:0;font-size:12px;color:#333650;font-family:ui-sans-serif,-apple-system,sans-serif;">
                &copy; 2026 NegocioApp &nbsp;&middot;&nbsp; Sistema de gestión para negocios
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

## Vista previa del diseño

```
┌─────────────────────────────────────┐
│           [ NegocioApp ]            │  ← logo con fondo púrpura
│                                     │
│  ┌───────────────────────────────┐  │
│  │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  │  ← barra púrpura superior
│  │                               │  │
│  │  Configura tu contraseña      │  │  ← título
│  │                               │  │
│  │  Recibimos una solicitud...   │  │  ← texto en gris
│  │                               │  │
│  │  [ Configurar contraseña → ]  │  │  ← botón púrpura
│  │                               │  │
│  │  ─────────────────────────   │  │
│  │  Este enlace expira en 1h...  │  │
│  │                               │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │ https://proyecto-app... │  │  │  ← fallback monospace
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
│                                     │
│    © 2026 NegocioApp · Sistema...   │  ← footer
└─────────────────────────────────────┘
```
