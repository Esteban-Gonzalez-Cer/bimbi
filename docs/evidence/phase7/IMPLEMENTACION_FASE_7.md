# Bimbi · Cómo se implementó y validó la Fase 7

La Fase 7 se trabajó el 22 de noviembre de 2026 en la rama `codex/phase7-notifications-plans`. La rama se creó desde la Fase 6 (`codex/phase6-running`), y se le unió el cierre de la Fase 5 (`48328c3`).

La especificación v0.4 pedía tres cosas:
- notificaciones FCM enviadas desde Firebase Console a temas, probadas con la app abierta, en segundo plano y cerrada, con el caso de force-stop documentado aparte;
- tres planes visibles: Free, Plus y Premium;
- pagos con la PaymentSheet de Stripe en modo de prueba, donde solo un pago verificado por el servidor cambia el acceso. Nunca se confía en una bandera del cliente.

Con el propietario se decidió además:
- revisar la interfaz de Running (Fase 6) y quitar la tarjeta "Bosque de Chapultepec";
- que los planes den solo extras pequeños, sin bloquear nada que ya existía;
- que cada pago sea un pase de 30 días;
- usar dos temas de notificaciones, Tips y Updates.

[Informe de cierre](REPORT.md) · [Registro de comandos](checks.txt) · [Fases](../../decisions/gates.md)

## 1. Punto de partida

La Fase 1 ya había probado las piezas básicas:
- el tema de prueba `bimbi_phase1` llegó en los tres estados;
- la función `paymentApi` creaba y verificaba pagos de prueba.

Faltaba la capa de producto:
- temas reales con su pantalla;
- un banner dentro de la app;
- planes escritos por el servidor, con recibos;
- ventajas que se desbloquean;
- una pantalla de planes diseñada.

Antes de cambiar nada se unió el cierre de la Fase 5 y se corrió `./scripts/check.sh` para confirmar que la base combinada pasaba.

## 2. Estructura del código

Las piezas nuevas siguen la guía de arquitectura de Flutter, como Home, Sleep y Focus. [Guía de Flutter](https://docs.flutter.dev/app-architecture/guide)

| Capa | Carpeta | Contenido |
|---|---|---|
| Dominio | `lib/domain/models/plan.dart` | `PlanTier`, `Entitlement` y `TestReceipt`. |
| Datos | `lib/data/repositories/entitlement_repository.dart`, `lib/data/services/messaging_service.dart` | Lectura del plan y los recibos; FCM detrás de una interfaz para poder probarlo. |
| Interfaz | `lib/ui/plans/`, `lib/ui/notifications/` | Modelos de vista con Riverpod, pantallas Plans y Notifications, y banner. |
| Servidor | `payment_demo/server/src/` | `applyGrant`, la transacción del plan y el recibo. |
| Android | `android/app/src/main/kotlin/com/bimbi/app/` | Canales `bimbi_tips` y `bimbi_updates`, y dos tonos nuevos. |

El estado usa solo `Notifier` y `Provider` de Riverpod, sin `setState`.

## 3. Running: pasada de interfaz

Running se reconstruyó con el lenguaje aprobado en Home, Sleep y Focus:
- encabezado con fecha y título;
- tarjeta de sesión con el mapa, un indicador de GPS y acciones del mismo ancho (Start, Pause, Resume, Finish, y Save run o Discard);
- métricas con `MetricTile`;
- historial con filas redondeadas;
- dos columnas en tablets horizontales.

Se eliminó `_PlaceCard`, la tarjeta con el nombre del parque. El marcador sigue en el mapa, porque la especificación pide un marcador de un lugar real. El controlador, el almacenamiento y la sincronización de carreras no cambiaron.

Se generó una página de comparación y el propietario aprobó la pantalla antes de seguir. [Running](../../../lib/features/running/presentation/running_page.dart) · [Render](running-390-states.png)

## 4. El servidor escribe el plan

Al verificar un pago, `paymentApi` ya comprobaba:
- que el pago es del usuario;
- el monto;
- la moneda `mxn`;
- `livemode=false`.

Ahora, cuando el estado es `succeeded`, hace dos escrituras:
1. Una transacción de Realtime Database con el Admin SDK sobre `users/{uid}/entitlements`, que deja `{tier, source, verifiedAt, expiresAt, grants}`.
2. El recibo `users/{uid}/payments/{paymentIntentId}` con `{plan, amount, currency, verifiedAt, testMode: true}`.

Las reglas del pase están en una función pura, `applyGrant`, para probarlas sin Firebase:
- **mismo plan activo:** se suman 30 días desde el vencimiento;
- **mejora o pase vencido:** 30 días desde ahora;
- **plan menor con uno mayor activo:** no cambia nada. Además, `createPaymentIntent` rechaza Plus si Premium está activo (`higher_plan_active`);
- **mismo pago dos veces:** `grants` guarda los pagos ya contados, así que no se suman días.

No hay webhook de Stripe. Si la app se cierra justo después de pagar, **Restore purchases** vuelve a pedir el mismo pago al servidor, que lo verifica y activa el plan. [Reglas de pago](../../../payment_demo/server/src/payments.ts) · [Función](../../../payment_demo/server/src/index.ts) · [Pruebas](../../../payment_demo/server/test/payments.test.cjs) · [ADR-005](../../adr/005-stripe-trusted-endpoint.md)

## 5. Reglas de Realtime Database

- `users/$uid/entitlements` y `users/$uid/payments`: el dueño verificado puede leerlos y nadie puede escribirlos. Solo el Admin SDK, que ignora las reglas, los escribe.
- `users/$uid/preferences/notificationTopics`: el dueño lee y escribe, pero solo los booleanos `tips` y `updates`.

Las pruebas nuevas del emulador intentan escribir un plan desde el cliente, leer el plan de otra cuenta y guardar campos extra. [Reglas](../../../firebase/database.rules.json) · [Pruebas](../../../firebase/emulator-tests/plans.test.cjs)

## 6. Ventajas en la app

`entitlementProvider` lee el plan del servidor y `planTierProvider` lo convierte en el plan vigente. Un pase vencido cuenta como Free. Sin sesión, el plan es Free.

Las ventajas son cosméticas y dependen solo de ese valor:
- **Plus:**
  - los colores Rose, Peach y Violet para el buddy, con una etiqueta "Plus" mientras están bloqueados;
  - los tonos Sparkle Rise y Lullaby Glow, que se generan con `scripts/generate_alarm_sounds.py`. En el editor de alarmas aparecen desactivados con "· Plus".
- **Premium:**
  - el tema Sunrise, con la paleta mandarina original de Brand Buddy;
  - una insignia en el avatar de Home.

Cuando el pase vence, el color y el tema vuelven a Lilac y lavanda sin borrar la elección. `plusToneGuardProvider` guarda las alarmas con tonos de Plus usando Dawn Chime, pero solo después de cargar el plan, para no cambiarlas mientras se lee. [Tokens](../../../lib/app/theme/bimbi_tokens.dart) · [Preferencias](../../../lib/app/preferences.dart) · [Ventajas](../../../lib/ui/plans/view_models/plan_perks.dart)

## 7. Pantalla Plans

La pantalla se abre desde Profile › Plans y contiene:
- el plan actual con su vencimiento y **Restore purchases**, o una indicación para iniciar sesión;
- el aviso **Test mode**;
- tres tarjetas, cada una con sus ventajas y una sola acción: *Get*, *Renew 30 days* o *Upgrade to Premium*. Las etiquetas *Current plan*, *Included* o *Recommended* indican la relación con el plan actual;
- los recibos de prueba.

En tablets horizontales usa dos columnas. La tarjeta se escribe en la PaymentSheet de Stripe, así que Bimbi nunca ve el número ni el CVC.

El propietario aprobó la pantalla con la página de comparación. [Plans](../../../lib/ui/plans/widgets/plans_screen.dart) · [Render](plans-390-free-plus-premium.png) · [Horizontal](plans-1006-landscape.png)

## 8. Notificaciones

- **Temas y canales.** `bimbi_tips` y `bimbi_updates` tienen un canal de Android con el mismo nombre, creado junto a los demás en `AlarmEngine.kt`. Cada uno se puede silenciar en los ajustes de Android. `bimbi_phase1` se da de baja una sola vez (clave `notify.legacy_removed`).
- **Consentimiento.** Al activar un tema se pide el permiso de notificaciones de Android. Si se niega, el tema queda apagado y se explica por qué. Al abrir la app no se pide nada.
- **Elección en la nube.** Las cuentas verificadas guardan `{tips, updates}`, de modo que un segundo dispositivo sigue los mismos temas.
- **Manejadores globales.** `InboxController` se conecta al iniciar la app:
  - un mensaje con la app abierta se convierte en banner;
  - una notificación tocada en segundo plano, o la que abrió la app, lleva a su pantalla;
  - el dato `destination` solo acepta `alarm`, `sleep`, `focus`, `running`, `profile`, `plans` y `notifications`; cualquier otro valor abre Home;
  - no se guardan ni registran tokens, IDs ni textos.
- **Pantalla Notifications.** Muestra el estado del permiso, con *Allowed* u *Open settings*, y los dos interruptores con su descripción. Se abre desde Profile › Notifications.

[Modelos de vista](../../../lib/ui/notifications/view_models/notifications.dart) · [Servicio](../../../lib/data/services/messaging_service.dart) · [Pantalla](../../../lib/ui/notifications/widgets/notifications_screen.dart) · [ADR-010](../../adr/010-notification-topics.md)

## 9. Publicación

El propietario autorizó publicar en el proyecto de desarrollo `bimbi-26ae2`:

```sh
./scripts/firebase.sh deploy --only database,functions:bimbi-phase1:paymentApi --project bimbi-26ae2 --non-interactive
```

Se publicaron las reglas combinadas de las Fases 5, 6 y 7 y la función actualizada. Después se probó en vivo, sin cuenta, que `paymentApi` responde 405 a GET y 401 sin token o con token inválido.

## 10. El banner que no se veía

En la primera prueba con la tablet, el propietario envió una campaña a `bimbi_tips` y no vio nada. Se revisó la tablet con adb:

1. Las preferencias tenían `notify.tips = true` y la cola de temas de Google Play services estaba vacía, así que la suscripción se había completado.
2. El registro de Android mostraba `FLTFireMsgReceiver: broadcast received` a las 22:10 y a las 22:14: el mensaje llegó a Bimbi.
3. En ambos momentos Bimbi estaba en primer plano, en la pantalla Notifications.

La causa estaba en dónde se dibujaba el banner. Estaba dentro del shell de pestañas, y Notifications (igual que Plans o el detalle de una carrera) se abre encima del shell, así que lo tapaba. Android no muestra notificaciones de una app abierta, por eso no se vio nada.

La corrección:
- el banner se movió a `MaterialApp.builder`, encima de todas las pantallas;
- `navigatorKeyProvider` permite que **Open** cierre las pantallas abiertas y regrese a las pestañas antes de ir al destino;
- una prueba nueva entrega un mensaje con Notifications abierta y comprueba el banner y el regreso.

Con la versión corregida instalada, el propietario confirmó que el banner aparece. [App](../../../lib/app/bimbi_app.dart) · [Prueba](../../../test/notifications_widget_test.dart)

## 11. Verificación en la Galaxy Tab A9

El propietario hizo y confirmó estas pruebas:
- **FCM con la app abierta:** aparece el banner con Dismiss y Open.
- **FCM en segundo plano:** aparece la notificación y al tocarla se abre Bimbi.
- **FCM con la app cerrada desde Recientes:** igual que en segundo plano.
- **Stripe, cancelar:** el plan sigue en Free.
- **Stripe, rechazo** con `4000 0000 0000 0002`: error y sin cambio de plan.
- **Stripe, éxito** con `4242 4242 4242 4242`: Plus activo con vencimiento y recibo.
- **Restore purchases:** "Your plan is up to date." y el vencimiento no cambia.
- **Ventajas de Plus:** se desbloquean los colores y los tonos.

## 12. Pruebas automáticas

- **Servidor:** alta, extensión, mejora, rechazo de un plan menor, idempotencia, modo en vivo y monto incorrecto.
- **Emulador de Firebase:** escritura del cliente denegada, lectura solo del dueño y esquema de preferencias.
- **Flutter:**
  - pase vencido con reloj inyectado;
  - ventajas bloqueadas y regreso a lo de siempre;
  - baja del tema anterior;
  - permiso negado;
  - sincronización de temas;
  - lista permitida de pantallas;
  - banner sobre otra pantalla;
  - Plans y Notifications a 360 dp con texto al 200 %.
- **Imágenes de referencia:** se actualizaron las de Running y Profile.

Todo corre con `./scripts/check.sh`. [Registro](checks.txt)

## 13. Pendiente

- Force-stop en la tablet: no debe llegar nada hasta abrir Bimbi.
- Mejora a Premium en la tablet, con el tema Sunrise y la insignia.
- Dos dispositivos con la misma cuenta: mismos temas, mismo plan y carreras sincronizadas.
- Recorrido con TalkBack de Running, Plans, Notifications y el banner.
