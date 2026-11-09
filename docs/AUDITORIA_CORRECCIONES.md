# Auditoría de correcciones: pagos, correos, app y señales

Rama de trabajo: `fix/pagos-correos-senales`, en el repositorio `SICAP` y en `SICAP-WEB`.
Estado: `[x]` corregido en código · `[ ]` pendiente · `[TÚ]` lo debes hacer tú porque requiere tus cuentas.

## 1. Compra de planes (web)

| # | Gravedad | Hallazgo | Evidencia | Estado |
|---|---|---|---|---|
| P1 | Crítica | El checkout de planes **no cobra**: pide la tarjeta, crea la institución desde el navegador y marca la orden como `paid` | `app/checkout/plan/page.tsx` (`handlePay`) | [x] |
| P2 | Crítica | Los eventos reales de Wompi se rechazan: las rutas de `signature.properties` se resolvían desde la raíz y no desde `data` | `api/wompi-webhook/route.ts`; docs de Wompi | [x] |
| P3 | Crítica | Wompi envía `environment: "prod"` y el esquema solo aceptaba `production` | `lib/schemas.ts` | [x] |
| P4 | Alta | El checksum de Wompi puede venir en mayúsculas y se comparaba sin normalizar | `api/wompi-webhook/route.ts` | [x] |
| P5 | Alta | El servidor lee `WOMPI_ENV`, pero solo existe `NEXT_PUBLIC_WOMPI_ENV`: en producción iría a sandbox | 7 rutas | [x] |
| P6 | Alta | `payment_link_id` se descartaba y la orden se buscaba solo por `reference` | `lib/schemas.ts`, webhook | [x] |
| P7 | Alta | Tres precios distintos: API 350.000, web 380.000 y `pricing_plans`; mensual contra anual con IVA | `checkout/plan`, `data/planes.ts` | [x] |
| P8 | Alta | La institución creada tras el pago no tenía `planMembership/current`, admin ni membresía | webhook | [x] |
| P9 | Alta | Si fallaba la activación se respondía 200 y Wompi no reintentaba | webhook | [x] |
| P10 | Alta | No se comparaba el monto pagado con el monto esperado | webhook | [x] |
| P11 | Alta | La página de confirmación decía "Pago recibido" aunque el pago fuera rechazado | `pago/plan/confirmacion` | [x] |
| P12 | Alta | `NEXT_PUBLIC_APP_URL` local apunta a Google Play: rompería el regreso desde Wompi | `.env.local` | [x] código · [TÚ] Vercel |
| P13 | Crítica | Mismo cobro simulado en **maniquíes, licencia SST y packs**. El webhook tampoco los entrega | `checkout/manikin`, `licencia-sst`, `pack` | [x] |
| P15 | Alta | Las rutas cobraban sin IVA y aceptaban un descuento enviado por el cliente | `api/checkout/*` | [x] |
| P16 | Media | `/checkout/resultado?status=approved` mostraba "aprobado" a cualquiera con ese enlace | `checkout/resultado` | [x] |
| P17 | Alta | La licencia no se renueva sola y la emisión de certificados aún no descuenta `certificateCredits` | `users` | [ ] |
| P14 | Media | La app móvil no compra planes: `PaymentService` no se usa y el admin está bloqueado allí | `payment_service.dart` | [x] enlace a la web |

## 2. Correos y contraseña

| # | Gravedad | Hallazgo | Estado |
|---|---|---|---|
| C1 | Alta | En la web, "¿Olvidaste tu contraseña?" era `href="#"`: no hacía nada | [x] página `/recuperar` |
| C2 | Alta | En la app exigía escribir el correo antes y no había flujo guiado | [x] diálogo |
| C3 | Alta | `RESEND_API_KEY` y `RESEND_FROM_EMAIL` no existen: ningún correo propio sale | [x] código · [TÚ] claves |
| C4 | Alta | Resend devuelve el error sin lanzarlo, así que los fallos pasaban en silencio | [x] |
| C5 | Media | Sin clave, importar el servicio fallaba al construir el cliente | [x] |
| C6 | Media | Datos del cliente insertados en HTML sin escapar | [x] |
| C7 | Media | La renovación de plan no enviaba comprobante | [x] |
| C8 | Media | `/login` leía `next`, pero el proxy envía `callbackUrl`, y aceptaba rutas externas | [x] |

## 3. Señales: maniquí y app

| # | Gravedad | Hallazgo | Estado |
|---|---|---|---|
| S1 | Crítica | El retroceso valía 30 de 100 puntos y siempre salía perfecto | [x] se mide por profundidad residual |
| S2 | Alta | Pausas y CCF nunca se calculaban | [x] |
| S3 | Alta | No se guardaba la señal de la sesión | [x] `sessions/{id}/compressions/serie` |
| S4 | Alta | Una compresión con liberación incompleta no se contaba | [x] umbral relativo al pico |
| S5 | Alta | Se mezclaba modo continuo con lectura bloqueante del sensor | [x] |
| S6 | Media | Una lectura inválida se trataba como 0 mm y `sensorOk` nunca bajaba | [x] |
| S7 | Media | Las 5 muestras del paquete eran copias de la misma lectura | [x] |
| S8 | Media | La referencia solo se tomaba al encender | [x] re-cero al iniciar sesión |
| S9 | Media | `triggerAudio` podía enviar START o STOP por accidente y nadie lo usa | [x] eliminado |
| S10 | Alta | El puntaje oficial lo sigue escribiendo el cliente (`sessions.metrics`) | [ ] |
| S11 | Alta | `telemetry/{id}` en RTDB se puede escribir con cualquier usuario autenticado | [ ] |
| S12 | Alta | Falta validar el sensor contra una referencia física | [TÚ] |

## 4. Vistas de la app

| # | Hallazgo | Estado |
|---|---|---|
| V1 | "Ajustes" del menú lateral no llevaba a ninguna parte | [x] abre editar perfil |
| V2 | Sin salida hacia los planes para un admin sin institución | [x] botón "Ver planes" |
| V3 | `flutter analyze` reporta 283 avisos, sobre todo de estilo | [ ] limpieza aparte |

## 5. Paso a paso que debes hacer

Lo marcado como [TÚ] no se puede hacer desde el código.

### Antes de probar
1. Revisa los cambios en la rama `fix/pagos-correos-senales` de ambos repositorios. Nada está confirmado ni publicado.
2. En `SICAP-WEB/.env.local` cambia `NEXT_PUBLIC_APP_URL` a `http://localhost:3000` para pruebas. En Vercel debe ser `https://siercp.com`.

### Correos
3. Crea una cuenta en [resend.com](https://resend.com) y verifica tu dominio con los registros DNS que te indique.
4. Crea una API key y agrégala en `.env.local` y en Vercel:
   - `RESEND_API_KEY`
   - `RESEND_FROM_EMAIL`, por ejemplo `SIERCP <no-reply@tudominio.com>`
5. Firebase envía el correo de recuperación por su cuenta. En Firebase Console → Authentication → Templates ponlo en español y revisa el remitente. Agrega `siercp.com` en Authentication → Settings → Authorized domains.

### Pagos en pruebas
6. En el panel de Wompi (modo pruebas) registra la URL de eventos: `https://TU-DOMINIO/api/wompi-webhook`.
7. Verifica en Vercel estas variables: `WOMPI_PRIVATE_KEY`, `WOMPI_EVENTS_SECRET`, `NEXT_PUBLIC_WOMPI_PUBLIC_KEY`, `NEXT_PUBLIC_WOMPI_ENV`.
8. Revisa en Firestore que `pricing_plans` tenga los precios correctos. El cliente paga exactamente lo que dice esa colección.
9. Publica una versión de prueba en Vercel y compra un plan con la tarjeta de pruebas de Wompi. Verifica:
   - aprobada: se crea la institución y el usuario queda como ADMIN
   - rechazada: la confirmación lo dice y no se crea nada

### Pagos reales
10. Cuando lo anterior funcione, cambia a llaves de producción (`prv_prod_…`, `pub_prod_…`) y `NEXT_PUBLIC_WOMPI_ENV=production`.
11. Repite la prueba con maniquíes, licencia SST y packs. Antes de vender packs o licencias resuelve P17: decide cuándo se descuenta un certificado y cómo se renueva la licencia.

### Maniquí
12. Instala o actualiza `Adafruit_VL53L0X` a la versión 1.1.0 o superior, carga `esp32_sicap/esp32_siercp.ino` y revisa el monitor serie.
13. Prueba compresiones con liberación completa e incompleta. Ajusta `ahaRecoilResidualMm` en `rcp_engine.dart`; hoy vale 10 mm y es un valor provisional.
14. Compara la profundidad del sensor contra una regla o una referencia. Antes de eso no presentes las métricas como certificables.

### Publicar
15. Confirma los cambios en ambos repositorios y compila la app (`flutter build apk`).
16. Antes de confirmar el repositorio `SICAP`, revisa los ~4.700 archivos marcados como borrados: `functions/` y `siercp_flutter/`. No uses `git add -A` sin mirarlos.
